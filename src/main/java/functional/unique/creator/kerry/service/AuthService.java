package functional.unique.creator.kerry.service;

import functional.unique.creator.kerry.dto.LoginRequest;
import functional.unique.creator.kerry.dto.RegisterRequest;
import functional.unique.creator.kerry.model.User;
import functional.unique.creator.kerry.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.bcrypt.BCrypt;
import org.springframework.stereotype.Service;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;

    public User register(String phone, String nickname, String password) {
        String hash = BCrypt.hashpw(password, BCrypt.gensalt());
        User user = User.builder()
                .phone(phone)
                .nickname(nickname)
                .passwordHash(hash)
                .roles(Set.of("USER"))
                .active(true)
                .invisibleMode(false)
                .build();
        return userRepository.save(user);
    }

    public User login(String phone, String password) {
        User user = userRepository.findByPhone(phone).orElseThrow(() -> new RuntimeException("User not found"));
        if (!BCrypt.checkpw(password, user.getPasswordHash())) throw new RuntimeException("Invalid password");
        return user;
    }

    public Object register(RegisterRequest req) {
        return register(req);
    }

    public Object login(LoginRequest req) {
        return login(req);
    }
}