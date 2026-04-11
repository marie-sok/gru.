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
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class MessageService {

    private final MessageRepository messageRepository;


    public MessageResponse sendMessage(String senderId, MessageRequest request) {
        Message message = Message.builder()
                .chatId(request.getChatId())
                .senderId(senderId)
                .content(request.getContent())
                .type(request.getType() != null ? request.getType() : MessageType.TEXT)
                .edited(false)
                .deleted(false)
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();

        Message saved = messageRepository.save(message);
        return mapToResponse(saved);
    }


    public MessageResponse editMessage(String messageId, String newContent) {
        Message message = messageRepository.findById(messageId)
                .orElseThrow(() -> new RuntimeException("Message not found"));

        message.setContent(newContent);
        message.setEdited(true);
        message.setUpdatedAt(Instant.now());

        Message updated = messageRepository.save(message);
        return mapToResponse(updated);
    }


    public void deleteMessage(String messageId) {
        Message message = messageRepository.findById(messageId)
                .orElseThrow(() -> new RuntimeException("Message not found"));

        message.setDeleted(true);
        message.setUpdatedAt(Instant.now());
        messageRepository.save(message);
    }


    public List<MessageResponse> getChatMessages(String chatId) {
        return messageRepository.findByChatIdAndDeletedFalseOrderByCreatedAtDesc(chatId)
                .stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    private MessageResponse mapToResponse(Message message) {
        MessageResponse response = new MessageResponse();
        response.setId(message.getId());
        response.setChatId(message.getChatId());
        response.setSenderId(message.getSenderId());
        response.setContent(message.getContent());
        response.setType(message.getType());
        response.setEdited(message.isEdited());
        response.setDeleted(message.isDeleted());
        response.setCreatedAt(message.getCreatedAt().toEpochMilli());
        response.setUpdatedAt(message.getUpdatedAt().toEpochMilli());
        return response;
    }

    public void save(Message msg) {
    }

    public Message send(Long senderId, Long receiverId, String content) {
        return null;
    }

    public void saveMessage(Message msg) {
    }

    public void markRead(Long msgId) {
    }
}