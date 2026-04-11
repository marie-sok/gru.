package gru.app.repository;

import gru.app.model.Message;
import org.springframework.data.mongodb.repository.MongoRepository;

import java.util.List;

public interface MessageRepository extends MongoRepository<Message, String> {

    List<Message> findByChatIdOrderByCreatedAtDesc(String chatId);

    List<Message> findByChatIdAndDeletedFalseOrderByCreatedAtDesc(String chatId);

    List<Message> findByChatId(String chatId);
}