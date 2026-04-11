package gru.app.service;

public interface JwtService {
    String extractUserId(String token);
}
