package gru.app.service;

import gru.app.model.Chat;
import gru.app.model.Message;
import lombok.RequiredArgsConstructor;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class ChatCacheService {

    private static final String PREFIX = "chat:";
    private static final Duration TTL = Duration.ofHours(12);

    private final RedisTemplate<String, Chat> redisTemplate;

    public Optional<Chat> getById(String chatId) {

        Chat chat = redisTemplate
                .opsForValue()
                .get(PREFIX + chatId);

        return Optional.ofNullable(chat);
    }

    public void put(Chat chat) {

        if (chat == null || chat.getId() == null) {
            return;
        }

        redisTemplate
                .opsForValue()
                .set(
                        PREFIX + chat.getId(),
                        chat,
                        TTL
                );
    }

    public void evict(String chatId) {

        redisTemplate.delete(PREFIX + chatId);
    }

    public boolean exists(String chatId) {

        return redisTemplate.hasKey(PREFIX + chatId);
    }

    public void refresh(Chat chat) {

        put(chat);
    }

    public void cacheChat(String chatId, List<Message> messages) {
    }

    public List<Message> getCachedChat(String chatId) {
        return List.of();
    }

    public void evictChatCache(String chatId) {
    }
}