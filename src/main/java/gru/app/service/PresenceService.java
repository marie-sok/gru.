package gru.app.service;

import lombok.RequiredArgsConstructor;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;

@Service
@RequiredArgsConstructor
public class PresenceService {

    private final StringRedisTemplate redis;

    private static final String KEY = "online:";

    public void setOnline(String userId) {
        redis.opsForValue().set(KEY + userId, "1", Duration.ofMinutes(5));
    }

    public void setOffline(String userId) {
        redis.delete(KEY + userId);
    }

    public boolean isOnline(String userId) {
        return Boolean.TRUE.equals(redis.hasKey(KEY + userId));
    }
}