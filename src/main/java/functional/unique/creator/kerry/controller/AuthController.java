package functional.unique.creator.kerry.controller;

import functional.unique.creator.kerry.model.User;
import functional.unique.creator.kerry.repository.UserRepository;
import functional.unique.creator.kerry.security.JwtUtil;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.Optional;

@RestController
@RequestMapping("/auth")
public class AuthController {

    private final UserRepository repo;
    private final BCryptPasswordEncoder encoder;
    private final JwtUtil jwtUtil;

    public AuthController(UserRepository repo,
                          BCryptPasswordEncoder encoder,
                          JwtUtil jwtUtil) {
        this.repo = repo;
        this.encoder = encoder;
        this.jwtUtil = jwtUtil;
    }

    @PostMapping("/login")
    public String login(@RequestParam String phone,
                        @RequestParam String password) {

        Optional<User> opt = repo.findByPhone(phone);
        if (opt.isEmpty()) return "User not found";

        User user = opt.get();
        if (!encoder.matches(password, user.getPasswordHash())) {
            return "Wrong password";
        }
        return jwtUtil.generateToken(user);
    }
}
