package gru.app.service;

import gru.app.dto.SendMessageRequest;
import gru.app.model.Attachment;
import gru.app.model.Chat;
import gru.app.model.Message;
import gru.app.model.ReplyReference;
import gru.app.repository.ChatRepository;
import gru.app.repository.MessageRepository;
import gru.app.repository.UserRepository;
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
    private final MediaStorageService mediaStorageService;
    private final UserRepository userRepository;
    private final ContentSafetyService contentSafetyService;

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

        contentSafetyService.validateText(text.trim());

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

        requireMessagingAllowed(senderId, receivers.getFirst());

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

    // MARK: - Send Attachment

    public Message sendAttachment(
            String senderId,
            String chatId,
            Attachment attachment,
            String replyToMessageId
    ) {

        requireUser(senderId);

        if (chatId == null || chatId.isBlank()) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Chat ID is required"
            );
        }

        if (attachment == null) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Attachment is required"
            );
        }

        Chat chat = getChat(chatId);
        requireParticipant(chat, senderId);

        ReplyReference replyTo = buildReplyReference(chat, replyToMessageId);

        List<String> receivers = chat.getParticipants()
                .stream()
                .filter(id -> id != null && !id.isBlank())
                .filter(id -> !id.equals(senderId))
                .distinct()
                .toList();

        if (receivers.size() != 1) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Attachment messages currently require a direct chat"
            );
        }

        requireMessagingAllowed(senderId, receivers.getFirst());

        Message message = new Message();
        message.setChatId(chat.getId());
        message.setSenderId(senderId);
        message.setReceiverId(receivers.getFirst());
        message.setText("");
        message.setCreatedAt(Instant.now());
        message.setDeliveredAt(null);
        message.setReadAt(null);
        message.setDeletedAt(null);
        message.setReaction(null);
        message.setAttachment(attachment);
        message.setReplyTo(replyTo);

        return messageRepository.save(message);
    }

    // MARK: - Reactions

    public Message setReaction(
            String userId,
            String messageId,
            String reaction
    ) {
        requireUser(userId);

        if (reaction == null || reaction.isBlank()) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Reaction is required"
            );
        }

        Message message = getMessage(messageId);
        Chat chat = getChat(message.getChatId());
        requireParticipant(chat, userId);
        message.setReaction(reaction.trim());
        return messageRepository.save(message);
    }

    public Message removeReaction(
            String userId,
            String messageId
    ) {
        requireUser(userId);
        Message message = getMessage(messageId);
        Chat chat = getChat(message.getChatId());
        requireParticipant(chat, userId);
        message.setReaction(null);
        return messageRepository.save(message);
    }

    // MARK: - Delete For Everyone

    public Message deleteForEveryone(
            String userId,
            String messageId
    ) {

        requireUser(userId);

        Message message = getMessage(messageId);

        if (message.getSenderId() == null || !message.getSenderId().equals(userId)) {
            throw new ResponseStatusException(
                    HttpStatus.FORBIDDEN,
                    "Only the sender can delete this message for everyone"
            );
        }

        message.setDeletedAt(Instant.now());
        message.setText("");
        message.setReplyTo(null);

        // Remove the physical media as well, then hard-delete from MongoDB.
        // The returned in-memory object is only a realtime tombstone so
        // connected clients can remove the bubble without a placeholder.
        if (message.getAttachment() != null) {
            mediaStorageService.deleteByRemoteURL(
                    message.getAttachment().getRemoteURL()
            );
        }

        messageRepository.deleteById(message.getId());

        return message;
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

    public Message edit(
            String senderId,
            String messageId,
            String newText
    ) {
        requireUser(senderId);

        if (messageId == null || messageId.isBlank()) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Message ID is required"
            );
        }

        if (newText == null || newText.isBlank()) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Text is required"
            );
        }

        Message message = messageRepository.findById(messageId)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND,
                        "Message not found"
                ));

        if (!senderId.equals(message.getSenderId())) {
            throw new ResponseStatusException(
                    HttpStatus.FORBIDDEN,
                    "Cannot edit someone else's message"
            );
        }

        message.setText(newText.trim());
        message.setIsEdited(true);
        message.setEditedAt(Instant.now());

        return messageRepository.save(message);
    }

    public void editMessage(
            Message message
    ) {
        if (message == null || message.getId() == null) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Message is required"
            );
        }
        messageRepository.save(message);
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

    private void requireMessagingAllowed(String senderId, String receiverId) {
        var sender = userRepository.findById(senderId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Sender not found"));
        var receiver = userRepository.findById(receiverId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Receiver not found"));

        boolean senderBlockedReceiver = sender.getBlockedUserIds() != null && sender.getBlockedUserIds().contains(receiverId);
        boolean receiverBlockedSender = receiver.getBlockedUserIds() != null && receiver.getBlockedUserIds().contains(senderId);

        if (senderBlockedReceiver || receiverBlockedSender) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Messaging is blocked between these users");
        }
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