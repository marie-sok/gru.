package gru.app.service;

import gru.app.dto.MessageResponse;
import gru.app.mapper.MessageMapper;
import gru.app.model.Message;
import gru.app.repository.MessageRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.function.Function;

@Service
@RequiredArgsConstructor
public class MessageService {

    private final MessageRepository repository;

    private final MessageMapper mapper;

    public List<MessageResponse> getMessages() {

        List<MessageResponse> list = new ArrayList<>();
        Function<? super Message<?>, ? extends MessageResponse> mapper1 = (Function<? super Message<?>, ? extends MessageResponse>) mapper::toResponse;
        for (Message<?> message : repository.findAll()) {
            MessageResponse messageResponse = mapper1.apply(message);
            list.add(messageResponse);
        }
        return list;
    }

    public MessageResponse editMessage(
            String id,
            String newContent
    ) {

        Message<?> message =
                repository.findById(id)
                        .orElseThrow();

        message.setContent(newContent);

        repository.save(message);

        return (MessageResponse) mapper.toResponse(message);
    }

    public void deleteMessage(String id) {

        repository.deleteById(id);
    }

    public Message<?> send(Long senderId, Long receiverId, String content) {
        return null;
    }


    public void markRead(Long msgId) {
    }

    public void save(Message<?> msg) {
    }

    public void editMessage(Message<?> msg) {
    }
}