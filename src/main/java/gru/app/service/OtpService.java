package gru.app.service;

import lombok.RequiredArgsConstructor;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.Random;

@Service
@RequiredArgsConstructor
public class OtpService {

    private final StringRedisTemplate redisTemplate;

    public String generateCode(String key) {
        String code = String.valueOf(100000 + new Random().nextInt(900000));
        redisTemplate.opsForValue().set(key, code, Duration.ofMinutes(3));
        return code;
    }

    public boolean verifyCode(String key, String code) {
        String stored = redisTemplate.opsForValue().get(key);
        return code.equals(stored);
    }
}