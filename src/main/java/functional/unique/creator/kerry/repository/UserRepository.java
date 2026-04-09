package functional.unique.creator.kerry.repository;

import functional.unique.creator.kerry.model.User;
import org.springframework.data.mongodb.repository.MongoRepository;

import java.util.Optional;

public interface UserRepository extends MongoRepository<User, String> {
    Optional<User> findByPhone(String phone);
}