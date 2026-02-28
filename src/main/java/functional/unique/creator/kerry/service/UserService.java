package functional.unique.creator.kerry.service;

import functional.unique.creator.kerry.model.User;
import functional.unique.creator.kerry.repository.UserRepository;
import org.springframework.security.crypto.bcrypt.BCrypt;
import org.springframework.stereotype.Service;

import java.util.Set;

@Service
public class UserService {

    private final UserRepository repo;

    public UserService(UserRepository repo) {
        this.repo = repo;
    }

    public User register(String phone, String nickname, String password) {

        if (repo.findByPhone(phone).isPresent())
            throw new RuntimeException("Phone already exists");

        String hash = BCrypt.hashpw(password, BCrypt.gensalt());

        User user = new User(
                phone,
                nickname,
                hash,
                Set.of("USER"),
                true
        );

        return repo.save(user);
    }

    public User findByPhone(String phone) {
        return repo.findByPhone(phone).orElse(null);
    }
}