package gru.app.service;

import gru.app.model.User;
import gru.app.security.JwtUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.Random;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final JwtUtil jwtUtil;

    private final Map<String, String> otpStore = new HashMap<>();

    public void sendCode(String phone) {
        String code = String.valueOf(1000 + new Random().nextInt(9000));
        otpStore.put(phone, code);

        System.out.println("OTP for " + phone + " = " + code);
    }

    public Map<String, String> verifyCode(String phone, String code) {

        String saved = otpStore.get(phone);

        if (saved == null || !saved.equals(code)) {
            throw new RuntimeException("Invalid OTP");
        }

        User user = User.builder()
                .phone(phone)
                .verified(true)
                .createdAt(Instant.now())
                .build();

        String access = jwtUtil.generateAccessToken(phone);
        String refresh = jwtUtil.generateRefreshToken(phone);

        Map<String, String> tokens = new HashMap<>();
        tokens.put("accessToken", access);
        tokens.put("refreshToken", refresh);

        otpStore.remove(phone);

        return tokens;
    }
}