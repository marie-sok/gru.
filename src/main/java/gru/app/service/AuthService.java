package gru.app.service;

import gru.app.dto.AuthResponse;
import gru.app.dto.LoginRequest;
import gru.app.dto.RegisterRequest;
import gru.app.model.User;
import gru.app.repository.UserRepository;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.Date;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    @Value("${jwt.secret}")
    private String jwtSecret;

    @Value("${jwt.expiration}")
    private long jwtExpirationMs;

    public AuthResponse register(RegisterRequest request) {
        User user = User.builder()
                .phone(request.getPhone())
                .name(request.getName())
                .nickname(request.getNickname())
                .showNickname(request.isShowNickname())
                .email(request.getEmail())
                .avatarUrl(request.getAvatarUrl())
                .birthday(request.getBirthday())
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .verified(false)
                .build();

        User saved = userRepository.save(user);
        return new AuthResponse(); // Можно вернуть токен сразу после верификации
    }

    public AuthResponse login(LoginRequest request) {
        User user = userRepository.findByPhone(request.getPhone())
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            throw new RuntimeException("Invalid credentials");
        }

        String token = Jwts.builder()
                .setSubject(user.getId())
                .setIssuedAt(new Date())
                .setExpiration(new Date(System.currentTimeMillis() + jwtExpirationMs))
                .signWith(SignatureAlgorithm.HS256, jwtSecret)
                .compact();

        AuthResponse response = new AuthResponse();
        response.setToken(token);
        response.setUserId(user.getId());
        return response;
    }
}