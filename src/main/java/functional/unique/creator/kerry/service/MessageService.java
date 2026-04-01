package functional.unique.creator.kerry.service;

import functional.unique.creator.kerry.model.Message;
import functional.unique.creator.kerry.repository.MessageRepository;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class MessageService {

    private  MessageRepository messageRepository;
    @Getter
    private Long currentUser;

    /**
     * send message
     */
    public Message send(Long senderId, Long receiverId, String content) {

        if (senderId == null || receiverId == null) {
            throw new RuntimeException("Sender or receiver is null");
        }

        if (content == null || content.isBlank()) {
            throw new RuntimeException("Message is empty");
        }

        Message message = Message.builder()
                .senderId(senderId)
                .receiverId(receiverId)
                .content(content)
                .read(false)
                .build();

        return messageRepository.save(message);
    }

    /**
     * history
     */
    public List<Message> getHistory(Long user1Id, Long user2Id) {

        if (user1Id == null || user2Id == null) {
            throw new RuntimeException("Users cannot be null");
        }

        return messageRepository
                .findTop50BySenderIdAndReceiverIdOrSenderIdAndReceiverIdOrderByCreatedAtAsc(
                        user1Id, user2Id,
                        user2Id, user1Id
                );
    }

    /**
     * view
     */
    public void markAsRead(Long senderId, Long receiverId) {

        List<Message> messages = messageRepository
                .findTop50BySenderIdAndReceiverIdOrSenderIdAndReceiverIdOrderByCreatedAtAsc(
                        senderId, receiverId,
                        receiverId, senderId
                );

        messages.stream()
                .filter(m -> !m.isRead() && m.getReceiverId().equals(receiverId))
                .forEach(m -> {
                    m.setRead(true);
                    messageRepository.save(m);
                });
    }

    public MessageRepository getMessageRepository() {
        return messageRepository;
    }

    /**
     * soft delete
     */
    public void delete(Long messageId) {

        Message message = messageRepository.findById(messageId)
                .orElseThrow(() -> new RuntimeException("Message not found"));

        message.setDeleted(true);
        messageRepository.save(message);
    }

    /**
     * redaction
     */
    public Message edit(Long messageId, String newContent) {

        if (newContent == null || newContent.isBlank()) {
            throw new RuntimeException("New content is empty");
        }

        Message message = messageRepository.findById(messageId)
                .orElseThrow(() -> new RuntimeException("Message not found"));

        message.setContent(newContent);
        return messageRepository.save(message);
    }

    public List<Message> history(Long currentUser, Long otherUserId) {
        return List.of();
    }

    public void setCurrentUser(Long currentUser) {
    }

    public void setMessageRepository(MessageRepository messageRepository) {
    }

    public void save(Message msg) {
    }
}