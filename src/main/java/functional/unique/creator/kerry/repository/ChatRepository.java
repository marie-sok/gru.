package functional.unique.creator.kerry.repository;

import functional.unique.creator.kerry.model.Chat;
import org.springframework.data.mongodb.repository.MongoRepository;

import java.util.List;

public interface ChatRepository extends MongoRepository<Chat, String> {
    List<Chat> findByParticipantsContains(String userId);
}