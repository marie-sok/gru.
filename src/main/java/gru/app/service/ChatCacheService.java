package gru.app.service;

import gru.app.model.Message;
import lombok.RequiredArgsConstructor;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.List;

@Service
@RequiredArgsConstructor
public class ChatCacheService {

    private final RedisTemplate<String, List<Message>> redisTemplate;

    private static final Duration CACHE_TTL = Duration.ofMinutes(10);


    public void cacheChat(String chatId, List<Message> messages) {
        redisTemplate.opsForValue().set(chatId, messages, CACHE_TTL);
    }


    public List<Message> getCachedChat(String chatId) {
        return redisTemplate.opsForValue().get(chatId);
    }


    public void evictChatCache(String chatId) {
        redisTemplate.delete(chatId);
    }
}