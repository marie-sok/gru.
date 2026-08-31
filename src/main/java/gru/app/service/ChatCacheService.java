package gru.app.service;

import gru.app.model.Chat;
import gru.app.model.Message;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

/**
 * Community release cache adapter.
 * MongoDB is the source of truth and the zero-budget release does not require Redis.
 * This API remains in place so the cache can be reintroduced later without changing callers.
 */
@Service
public class ChatCacheService {

    public Optional<Chat> getById(String chatId) {
        return Optional.empty();
    }

    public void put(Chat chat) {
    }

    public void evict(String chatId) {
    }

    public boolean exists(String chatId) {
        return false;
    }

    public void refresh(Chat chat) {
    }

    public void cacheChat(String chatId, List<Message> messages) {
    }

    public List<Message> getCachedChat(String chatId) {
        return List.of();
    }

    public void evictChatCache(String chatId) {
    }
}
