package gru.app.service;

import gru.app.dto.SendMessageRequest;
import gru.app.model.Message;
import gru.app.repository.MessageRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;

@Service
@RequiredArgsConstructor
public class MessageService {

    private final MessageRepository messageRepository;

    public Message send(
            String senderId,
            SendMessageRequest request
    ) {

        Message message = new Message();

        message.setChatId(request.getChatId());
        message.setSenderId(senderId);
        message.setText(request.getText());
        message.setCreatedAt(Instant.now());

        return messageRepository.save(message);
    }

    public List<Message> findByChatId(String chatId) {
        return messageRepository.findByChatIdOrderByCreatedAtAsc(chatId);
    }

    public Message save(Message message) {
        return messageRepository.save(message);
    }

    public void editMessage(Message message) {
        messageRepository.save(message);
    }

    public void markRead(String messageId) {

        Message message = messageRepository.findById(messageId)
                .orElseThrow(() -> new RuntimeException("Message not found"));

        messageRepository.save(message);
    }
}