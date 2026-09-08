package gru.app.service;

import gru.app.dto.E2EEMessageRequest;
import gru.app.model.Chat;
import gru.app.model.Message;
import gru.app.model.User;
import gru.app.repository.ChatRepository;
import gru.app.repository.MessageRepository;
import gru.app.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class E2EEMessageService {

    private final MessageRepository messageRepository;
    private final ChatRepository chatRepository;
    private final UserRepository userRepository;

    public Message send(String senderId, E2EEMessageRequest request) {
        User sender = requireUser(senderId);
        if (request == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Request is required");
        }

        requireText(request.getChatId(), "chatId", 120);
        requireText(request.getEncryptionVersion(), "encryptionVersion", 40);
        if (!"gru-e2ee-v1".equals(request.getEncryptionVersion())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unsupported encryption version");
        }

        validateBase64(request.getEncryptedPayload(), "encryptedPayload", 16, 256_000);
        validateBase64(request.getSenderEphemeralPublicKey(), "senderEphemeralPublicKey", 32, 32);
        validateBase64(request.getSignature(), "signature", 64, 64);
        requireText(request.getSenderKeyFingerprint(), "senderKeyFingerprint", 128);

        if (sender.getE2eeSigningPublicKey() == null || sender.getE2eeKeyAgreementPublicKey() == null) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Sender E2EE identity key is not registered");
        }

        Chat chat = chatRepository.findById(request.getChatId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Chat not found"));

        List<String> participants = chat.getParticipants();
        if (participants == null || !participants.contains(senderId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Not a chat participant");
        }

        List<String> receivers = participants.stream()
                .filter(id -> id != null && !id.isBlank())
                .filter(id -> !id.equals(senderId))
                .distinct()
                .toList();
        if (receivers.size() != 1) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "E2EE v1 supports direct chats only");
        }

        User receiver = requireUser(receivers.getFirst());
        requireMessagingAllowed(sender, receiver);
        if (receiver.getE2eeKeyAgreementPublicKey() == null || receiver.getE2eeSigningPublicKey() == null) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Receiver E2EE identity key is not registered");
        }

        Message message = new Message();
        message.setChatId(chat.getId());
        message.setSenderId(senderId);
        message.setReceiverId(receiver.getId());
        message.setText(null);
        message.setEncryptedPayload(request.getEncryptedPayload());
        message.setEncryptionVersion(request.getEncryptionVersion());
        message.setSenderEphemeralPublicKey(request.getSenderEphemeralPublicKey());
        message.setE2eeSignature(request.getSignature());
        message.setSenderKeyFingerprint(request.getSenderKeyFingerprint());
        message.setCreatedAt(Instant.now());
        message.setDeliveredAt(null);
        message.setReadAt(null);
        return messageRepository.save(message);
    }

    private User requireUser(String userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));
    }

    private void requireMessagingAllowed(User sender, User receiver) {
        Set<String> senderBlocked = sender.getBlockedUserIds();
        Set<String> receiverBlocked = receiver.getBlockedUserIds();
        if ((senderBlocked != null && senderBlocked.contains(receiver.getId()))
                || (receiverBlocked != null && receiverBlocked.contains(sender.getId()))) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Messaging is blocked");
        }
    }

    private void requireText(String value, String field, int max) {
        if (value == null || value.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, field + " is required");
        }
        if (value.length() > max) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, field + " is too long");
        }
    }

    private void validateBase64(String encoded, String field, int minBytes, int maxBytes) {
        requireText(encoded, field, maxBytes * 2 + 16);
        try {
            byte[] decoded = Base64.getDecoder().decode(encoded);
            if (decoded.length < minBytes || decoded.length > maxBytes) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, field + " has invalid size");
            }
        } catch (IllegalArgumentException error) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, field + " must be base64");
        }
    }
}
