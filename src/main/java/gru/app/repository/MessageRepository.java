package gru.app.repository;

import gru.app.model.Message;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.data.mongodb.repository.Query;

import java.util.List;
import java.util.Optional;

public interface MessageRepository
        extends MongoRepository<Message, String> {

    List<Message> findByChatIdOrderByCreatedAtAsc(String chatId);
    List<Message> findBySenderId(String senderId);
    Optional<Message> findFirstBySenderIdAndE2eeClientMessageId(String senderId, String e2eeClientMessageId);

    @Query(value = "{ 'attachment.remoteURL': ?0 }")
    Optional<Message> findFirstByAttachmentRemoteURL(String remoteURL);
}
