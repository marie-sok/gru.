package gru.app.service;

import gru.app.dto.AuthResponse;
import gru.app.dto.LoginRequest;
import gru.app.dto.RegisterRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final JwtService jwtService;

    public String login(LoginRequest user) {

        return jwtService.generateToken(
                user.getId()
        );
    }

    public AuthResponse register(RegisterRequest request) {
        return null;
    }
}