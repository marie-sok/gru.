package gru.app.service;

import gru.app.dto.AuthResponse;
import gru.app.dto.VerifyRequest;
import gru.app.security.JwtUtil;
import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class AuthService {

    private final JwtUtil jwtUtil;

    private final Map<String, String> codes = new ConcurrentHashMap<>();

    public AuthService(JwtUtil jwtUtil) {
        this.jwtUtil = jwtUtil;
    }

    public void sendCode(String phone) {
        String code = "1234";
        codes.put(phone, code);
    }

    public AuthResponse verify(VerifyRequest req) {

        String saved = codes.get(req.getPhone());

        if (saved == null || !saved.equals(req.getCode())) {
            throw new RuntimeException("Invalid code");
        }

        String token = jwtUtil.generateToken(req.getPhone());
        return new AuthResponse(token);
    }
}