package gru.app.service;

import gru.app.model.Message;
import gru.app.repository.MessageRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;

@Service
@RequiredArgsConstructor
public class MessageService {

    private final MessageRepository repo;

    public Message save(String chatId, String senderId, String receiverId, String content) {

        Message msg = Message.builder()
                .chatId(chatId)
                .senderId(senderId)
                .receiverId(receiverId)
                .content(content)
                .type(gru.app.model.MessageType.TEXT)
                .read(false)
                .deleted(false)
                .createdAt(Instant.now())
                .build();

        return repo.save(msg);
    }

    public List<Message> getChat(String chatId) {
        return repo.findByChatIdOrderByCreatedAtAsc(chatId);
    }

    public void markRead(String messageId) {
        repo.findById(messageId).ifPresent(m -> {
            m.setRead(true);
            repo.save(m);
        });
    }
}