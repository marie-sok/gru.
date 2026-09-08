package gru.app.service;

import gru.app.dto.E2EEMessageRequest;
import gru.app.model.Chat;
import gru.app.model.Message;
import gru.app.model.ReplyReference;
import gru.app.model.User;
import gru.app.repository.ChatRepository;
import gru.app.repository.MessageRepository;
import gru.app.repository.UserRepository;
import gru.app.security.E2EECryptoVerifier;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.Set;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class E2EEMessageService {

    private final MessageRepository messageRepository;
    private final ChatRepository chatRepository;
    private final UserRepository userRepository;
    private final E2EECryptoVerifier cryptoVerifier;

    public Message send(String senderId, E2EEMessageRequest request) {
        User sender = requireUser(senderId);
        validateRequest(request);

        Chat chat = requireDirectChat(request.getChatId(), senderId);
        User receiver = requireReceiver(chat, senderId, sender);

        Message existing = messageRepository
                .findFirstBySenderIdAndE2eeClientMessageId(senderId, request.getClientMessageId())
                .orElse(null);
        if (existing != null) {
            if (!chat.getId().equals(existing.getChatId())) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "clientMessageId already used in another chat");
            }
            if (existing.getSenderSigningPublicKey() == null) {
                existing.setSenderSigningPublicKey(sender.getE2eeSigningPublicKey());
                existing = messageRepository.save(existing);
            }
            return existing;
        }

        verifyEnvelope(sender, receiver, chat, request);

        ReplyReference replyReference = buildReplyReference(chat, request.getReplyToMessageId());

        Message message = new Message();
        message.setChatId(chat.getId());
        message.setSenderId(senderId);
        message.setReceiverId(receiver.getId());
        message.setText("");
        message.setReplyTo(replyReference);
        applyEnvelope(message, sender, request);
        message.setCreatedAt(Instant.now());
        message.setDeliveredAt(null);
        message.setReadAt(null);
        return messageRepository.save(message);
    }

    public Message edit(String senderId, String messageId, E2EEMessageRequest request) {
        User sender = requireUser(senderId);
        validateRequest(request);

        if (messageId == null || messageId.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Message ID is required");
        }

        Message message = messageRepository.findById(messageId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Message not found"));
        if (!senderId.equals(message.getSenderId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Cannot edit someone else's message");
        }
        if (message.getHiddenForUserIds() != null && message.getHiddenForUserIds().contains(senderId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Message not found");
        }
        if (message.getEncryptedPayload() == null || message.getE2eeClientMessageId() == null) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Message is not E2EE");
        }
        if (message.getAttachment() != null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Media messages cannot be edited as text");
        }
        if (!message.getChatId().equals(request.getChatId())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Chat ID mismatch");
        }

        Chat chat = requireDirectChat(message.getChatId(), senderId);
        User receiver = requireReceiver(chat, senderId, sender);
        if (!receiver.getId().equals(message.getReceiverId())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Message receiver mismatch");
        }

        Message duplicate = messageRepository
                .findFirstBySenderIdAndE2eeClientMessageId(senderId, request.getClientMessageId())
                .orElse(null);
        if (duplicate != null && !message.getId().equals(duplicate.getId())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "clientMessageId already used");
        }

        verifyEnvelope(sender, receiver, chat, request);
        applyEnvelope(message, sender, request);
        message.setText("");
        message.setIsEdited(true);
        message.setEditedAt(Instant.now());
        return messageRepository.save(message);
    }

    private void validateRequest(E2EEMessageRequest request) {
        if (request == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Request is required");
        }

        requireText(request.getChatId(), "chatId", 120);
        requireText(request.getClientMessageId(), "clientMessageId", 64);
        requireUUID(request.getClientMessageId(), "clientMessageId");
        requireText(request.getEncryptionVersion(), "encryptionVersion", 40);
        if (!"gru-e2ee-v1".equals(request.getEncryptionVersion())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unsupported encryption version");
        }

        validateBase64(request.getEncryptedPayload(), "encryptedPayload", 16, 256_000);
        validateBase64(request.getSenderEphemeralPublicKey(), "senderEphemeralPublicKey", 32, 32);
        validateBase64(request.getSignature(), "signature", 64, 64);
        requireText(request.getSenderKeyFingerprint(), "senderKeyFingerprint", 128);
    }

    private Chat requireDirectChat(String chatId, String senderId) {
        Chat chat = chatRepository.findById(chatId)
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
        return chat;
    }

    private User requireReceiver(Chat chat, String senderId, User sender) {
        String receiverId = chat.getParticipants().stream()
                .filter(id -> id != null && !id.isBlank())
                .filter(id -> !id.equals(senderId))
                .distinct()
                .findFirst()
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Receiver not found"));

        User receiver = requireUser(receiverId);
        requireMessagingAllowed(sender, receiver);

        if (sender.getE2eeSigningPublicKey() == null || sender.getE2eeKeyAgreementPublicKey() == null) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Sender E2EE identity key is not registered");
        }
        if (receiver.getE2eeKeyAgreementPublicKey() == null || receiver.getE2eeSigningPublicKey() == null) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Receiver E2EE identity key is not registered");
        }
        return receiver;
    }

    private void verifyEnvelope(User sender, User receiver, Chat chat, E2EEMessageRequest request) {
        if (!cryptoVerifier.fingerprintMatches(sender.getE2eeSigningPublicKey(), request.getSenderKeyFingerprint())) {
            throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY, "Sender key fingerprint mismatch");
        }
        if (!cryptoVerifier.verifyMessageSignature(
                sender.getE2eeSigningPublicKey(),
                request.getEncryptionVersion(),
                chat.getId(),
                sender.getId(),
                receiver.getId(),
                request.getClientMessageId(),
                request.getSenderEphemeralPublicKey(),
                request.getEncryptedPayload(),
                request.getSenderKeyFingerprint(),
                request.getSignature()
        )) {
            throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY, "Invalid E2EE envelope signature");
        }
    }

    private void applyEnvelope(Message message, User sender, E2EEMessageRequest request) {
        message.setE2eeClientMessageId(request.getClientMessageId());
        message.setEncryptedPayload(request.getEncryptedPayload());
        message.setEncryptionVersion(request.getEncryptionVersion());
        message.setSenderEphemeralPublicKey(request.getSenderEphemeralPublicKey());
        message.setE2eeSignature(request.getSignature());
        message.setSenderKeyFingerprint(request.getSenderKeyFingerprint());
        message.setSenderSigningPublicKey(sender.getE2eeSigningPublicKey());
    }

    private ReplyReference buildReplyReference(Chat chat, String replyId) {
        if (replyId == null || replyId.isBlank()) {
            return null;
        }
        Message original = messageRepository.findById(replyId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Reply message not found"));
        if (!chat.getId().equals(original.getChatId())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Reply message belongs to another chat");
        }
        return new ReplyReference(original.getId(), original.getSenderId(), "");
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

    private void requireUUID(String value, String field) {
        try {
            UUID.fromString(value);
        } catch (IllegalArgumentException error) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, field + " must be a UUID");
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
