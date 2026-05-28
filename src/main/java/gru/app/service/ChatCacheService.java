package gru.app.service;

import gru.app.model.Message;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.List;

@Service
@RequiredArgsConstructor
public class ChatCacheService {

    private static final String CACHE_PREFIX =
            "chat:";

    private final RedisTemplate<String, List<Message>>
            redisTemplate;

    @Value("${chat.cache.ttl-minutes}")
    private long ttlMinutes;

    public void saveMessages(
            String chatId,
            List<Message> messages
    ) {

        redisTemplate.opsForValue().set(
                CACHE_PREFIX + chatId,
                messages,
                Duration.ofMinutes(ttlMinutes)
        );
    }

    public List<Message> getMessages(
            String chatId
    ) {

        return redisTemplate.opsForValue().get(
                CACHE_PREFIX + chatId
        );
    }

    public List<Message> getCachedChat(String chatId) {
        return List.of();
    }

    public void cacheChat(String chatId, List<Message> messages) {
    }

    public void evictChatCache(String chatId) {
    }
}