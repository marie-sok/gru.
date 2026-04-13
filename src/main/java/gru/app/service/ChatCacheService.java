package gru.app.service;

import gru.app.model.Message;
import lombok.RequiredArgsConstructor;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ChatCacheService {

    private final RedisTemplate<String, Object> redis;

    private static final String KEY = "chat:";

    public void saveMessages(String chatId, List<Message<?>> messages) {
        redis.opsForValue().set(KEY + chatId, messages);
    }

    public List<Message<?>> getMessages(String chatId) {
        return (List<Message<?>>) redis.opsForValue().get(KEY + chatId);
    }
}