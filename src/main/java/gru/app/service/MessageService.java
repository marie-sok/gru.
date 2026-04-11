package gru.app.service;

import gru.app.dto.MessageRequest;
import gru.app.dto.MessageResponse;
import gru.app.model.Message;
import gru.app.model.MessageType;
import gru.app.repository.MessageRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;

@Service
@RequiredArgsConstructor
public class MessageService {

    private final MessageRepository repo;

    // ===== SEND MESSAGE =====
    public Message<?> sendMessage(String senderId, String chatId, String content) {

        Message<?> msg = Message.builder()
                .chatId(chatId)
                .senderId(senderId)
                .content(content)
                .type(MessageType.TEXT)
                .read(false)
                .deleted(false)
                .createdAt(Instant.now())
                .build();

        return repo.save(msg);
    }

    // ===== GET CHAT HISTORY =====
    public List<Message<?>> getChatMessages(String chatId) {
        return repo.findByChatIdOrderByCreatedAtAsc(chatId);
    }

    // ===== MARK READ =====
    public void markRead(String messageId) {
        repo.findById(messageId).ifPresent(msg -> {
            msg.setRead(true);
            repo.save(msg);
        });
    }

    // ===== DELETE MESSAGE =====
    public void delete(String messageId) {
        repo.findById(messageId).ifPresent(msg -> {
            msg.setDeleted(true);
            repo.save(msg);
        });
    }

    public Message<?> send(Long senderId, Long receiverId, String content) {
        return null;
    }

    public void save(Message<?> msg) {
    }

    public Message<?> sendInternal(String senderId, String receiverId, String content) {
        return null;
    }


    public void markAsRead(String messageId) {
    }

    public MessageResponse sendMessage(String senderId, MessageRequest request) {
        return null;
    }

    public MessageResponse editMessage(String id, String newContent) {
        return null;
    }

    public void deleteMessage(String id) {
    }
}