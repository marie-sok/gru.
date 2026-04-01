package functional.unique.creator.kerry.service;

import functional.unique.creator.kerry.model.Message;
import functional.unique.creator.kerry.repository.MessageRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class MessageService {

    private MessageRepository messageRepository;

    public void saveMessage(Message message) {
        messageRepository.save(message);
    }

    public List<Message> getHistory(Long user1, Long user2) {
        return messageRepository
                .findTop50BySenderIdAndReceiverIdOrSenderIdAndReceiverIdOrderByTimestampAsc(user1, user2, user2, user1);
    }

    public void markRead(Long messageId) {
        messageRepository.findById(messageId).ifPresent(msg -> {
            msg.setRead(true);
            messageRepository.save(msg);
        });
    }

    public Message send(Long senderId, Long receiverId, String content) {
        return null;
    }

    public void save(Message msg) {
    }

    public List<Message> history(Long currentUser, Long otherUserId) {
        return List.of();
    }
}