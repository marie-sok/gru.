package gru.app.service;

import gru.app.dto.SendMessageRequest;
import gru.app.model.Chat;
import gru.app.model.Message;
import gru.app.model.ReplyReference;
import gru.app.repository.ChatRepository;
import gru.app.repository.MessageRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class MessageService {

    private final MessageRepository messageRepository;
    private final ChatRepository chatRepository;

    // MARK: - Send

    public Message send(
            String senderId,
            SendMessageRequest request
    ) {

        requireUser(senderId);

        if (request == null) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Request is required"
            );
        }

        String chatId = request.getChatId();

        if (chatId == null || chatId.isBlank()) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Chat ID is required"
            );
        }

        String text = request.getText();

        if (text == null || text.trim().isEmpty()) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Message text is required"
            );
        }

        Chat chat = getChat(chatId);

        requireParticipant(
                chat,
                senderId
        );

        ReplyReference replyTo =
                buildReplyReference(
                        chat,
                        request.getReplyToMessageId()
                );

        List<String> receivers =
                chat.getParticipants()
                        .stream()
                        .filter(id ->
                                id != null &&
                                        !id.isBlank()
                        )
                        .filter(id ->
                                !id.equals(senderId)
                        )
                        .distinct()
                        .toList();

        if (receivers.isEmpty()) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Chat has no receiver"
            );
        }

        if (receivers.size() > 1) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Group messages are not supported yet"
            );
        }

        Message message =
                new Message();

        message.setChatId(
                chat.getId()
        );

        message.setSenderId(
                senderId
        );

        message.setReceiverId(
                receivers.getFirst()
        );

        message.setText(
                text.trim()
        );

        message.setCreatedAt(
                Instant.now()
        );

        message.setDeliveredAt(
                null
        );

        message.setReadAt(
                null
        );

        message.setReplyTo(
                replyTo
        );

        return messageRepository.save(
                message
        );
    }

    // MARK: - History

    public List<Message> getMessages(
            String userId,
            String chatId
    ) {

        requireUser(userId);

        Chat chat =
                getChat(chatId);

        requireParticipant(
                chat,
                userId
        );

        return messageRepository
                .findByChatIdOrderByCreatedAtAsc(
                        chatId
                );
    }

    // MARK: - Delivered

    public Message markDelivered(
            String userId,
            String messageId
    ) {

        requireUser(userId);

        Message message =
                getMessage(messageId);

        requireReceiver(
                message,
                userId
        );

        if (message.getDeliveredAt() == null) {

            message.setDeliveredAt(
                    Instant.now()
            );

            message =
                    messageRepository.save(
                            message
                    );
        }

        return message;
    }

    // MARK: - Read Single

    public Message markRead(
            String userId,
            String messageId
    ) {

        requireUser(userId);

        Message message =
                getMessage(messageId);

        requireReceiver(
                message,
                userId
        );

        Instant now =
                Instant.now();

        if (message.getDeliveredAt() == null) {

            message.setDeliveredAt(
                    now
            );
        }

        if (message.getReadAt() == null) {

            message.setReadAt(
                    now
            );
        }

        return messageRepository.save(
                message
        );
    }

    // MARK: - Read Entire Chat

    public List<Message> markChatRead(
            String userId,
            String chatId
    ) {

        requireUser(userId);

        Chat chat =
                getChat(chatId);

        requireParticipant(
                chat,
                userId
        );

        List<Message> messages =
                messageRepository
                        .findByChatIdOrderByCreatedAtAsc(
                                chatId
                        );

        Instant now =
                Instant.now();

        List<Message> changed =
                new ArrayList<>();

        for (Message message : messages) {

            if (!userId.equals(
                    message.getReceiverId()
            )) {
                continue;
            }

            boolean didChange =
                    false;

            if (message.getDeliveredAt() == null) {

                message.setDeliveredAt(
                        now
                );

                didChange =
                        true;
            }

            if (message.getReadAt() == null) {

                message.setReadAt(
                        now
                );

                didChange =
                        true;
            }

            if (didChange) {

                changed.add(
                        messageRepository.save(
                                message
                        )
                );
            }
        }

        return changed;
    }

    // MARK: - Save

    public Message save(
            Message message
    ) {

        return messageRepository.save(
                message
        );
    }

    // MARK: - Edit

    public void editMessage(
            Message message
    ) {

        if (
                message == null ||
                        message.getId() == null
        ) {

            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Message is required"
            );
        }

        messageRepository.save(
                message
        );
    }

    // MARK: - Find By Chat

    public List<Message> findByChatId(
            String chatId
    ) {

        return messageRepository
                .findByChatIdOrderByCreatedAtAsc(
                        chatId
                );
    }

    // MARK: - Reply

    private ReplyReference buildReplyReference(
            Chat chat,
            String replyToMessageId
    ) {

        if (
                replyToMessageId == null ||
                        replyToMessageId.isBlank()
        ) {
            return null;
        }

        String messageId =
                replyToMessageId.trim();

        Message original =
                getMessage(messageId);

        if (
                original.getChatId() == null ||
                        !original.getChatId().equals(
                                chat.getId()
                        )
        ) {

            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Reply message does not belong to this chat"
            );
        }

        return new ReplyReference(
                original.getId(),
                original.getSenderId(),
                original.getText()
        );
    }

    // MARK: - Helpers

    private Chat getChat(
            String chatId
    ) {

        return chatRepository
                .findById(chatId)
                .orElseThrow(
                        () ->
                                new ResponseStatusException(
                                        HttpStatus.NOT_FOUND,
                                        "Chat not found"
                                )
                );
    }

    private Message getMessage(
            String messageId
    ) {

        if (
                messageId == null ||
                        messageId.isBlank()
        ) {

            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Message ID is required"
            );
        }

        return messageRepository
                .findById(messageId)
                .orElseThrow(
                        () ->
                                new ResponseStatusException(
                                        HttpStatus.NOT_FOUND,
                                        "Message not found"
                                )
                );
    }

    private void requireUser(
            String userId
    ) {

        if (
                userId == null ||
                        userId.isBlank()
        ) {

            throw new ResponseStatusException(
                    HttpStatus.UNAUTHORIZED,
                    "Unauthorized"
            );
        }
    }

    private void requireParticipant(
            Chat chat,
            String userId
    ) {

        List<String> participants =
                chat.getParticipants();

        if (
                participants == null ||
                        !participants.contains(userId)
        ) {

            throw new ResponseStatusException(
                    HttpStatus.FORBIDDEN,
                    "You are not a participant of this chat"
            );
        }
    }

    private void requireReceiver(
            Message message,
            String userId
    ) {

        if (
                message.getReceiverId() == null ||
                        !message.getReceiverId().equals(userId)
        ) {

            throw new ResponseStatusException(
                    HttpStatus.FORBIDDEN,
                    "Only the receiver can update message status"
            );
        }
    }

    public void markRead(String s) {
    }
}