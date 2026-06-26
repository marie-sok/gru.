package gru.app.repository;

import gru.app.model.User;
import org.springframework.data.mongodb.repository.MongoRepository;

import java.util.List;
import java.util.Optional;

public interface UserRepository extends MongoRepository<User, String> {

    Optional<User> findByPhone(String phone);

    List<User> findByNicknameContainingIgnoreCase(String nickname);
}