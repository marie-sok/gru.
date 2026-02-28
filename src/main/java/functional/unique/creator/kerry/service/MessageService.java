package functional.unique.creator.kerry.service;

import functional.unique.creator.kerry.model.Message;
import functional.unique.creator.kerry.repository.MessageRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class MessageService {

    private final MessageRepository repo;

    public MessageService(MessageRepository repo) {
        this.repo = repo;
    }

    public Message save(Long sender, Long receiver, String content) {
        Message m = new Message();
        m.setSenderId(sender);
        m.setReceiverId(receiver);
        m.setContent(content);
        return repo.save(m);
    }

    public List<Message> history(Long u1, Long u2) {
        return repo.findTop50BySenderIdAndReceiverIdOrSenderIdAndReceiverIdOrderByTimestampAsc(
                u1, u2, u2, u1
        );
    }

    public Message send(Long senderId, Long receiverId, String text) {
        return null;
    }
}