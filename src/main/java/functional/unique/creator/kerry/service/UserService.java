package functional.unique.creator.kerry.service;

import functional.unique.creator.kerry.model.User;
import functional.unique.creator.kerry.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.bcrypt.BCrypt;
import org.springframework.stereotype.Service;

import java.util.Set;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository repo;

    public User register(String phone, String nickname, String password) {
        String hash = BCrypt.hashpw(password, BCrypt.gensalt());

        User user = User.builder()
                .phone(phone)
                .nickname(nickname)
                .passwordHash(hash)
                .roles(Set.of("USER"))
                .active(true)
                .build();

        return repo.save(user);
    }
}
