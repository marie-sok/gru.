package gru.app.security;

public interface JwtService {
    String extractUserId(String token);

    String generateToken(String s);
}
