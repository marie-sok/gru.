package functional.unique.creator.kerry.service;

import functional.unique.creator.kerry.model.Message;
import functional.unique.creator.kerry.repository.MessageRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class MessageService {

    private final MessageRepository repo;

    public Message sendMessage(String sender, String receiver, String content) {
        Message message = Message.builder()
                .senderPhone(sender)
                .receiverPhone(receiver)
                .content(content)
                .timestamp(LocalDateTime.now())
                .build();
        return repo.save(message);
    }

    public List<Message> getHistory(String sender, String receiver) {
        return repo.findBySenderPhoneAndReceiverPhoneOrderByTimestampAsc(sender, receiver);
    }
}
