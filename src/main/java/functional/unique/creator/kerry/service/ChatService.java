package functional.unique.creator.kerry.service;

import functional.unique.creator.kerry.dto.MessageRequest;
import functional.unique.creator.kerry.model.Message;
import functional.unique.creator.kerry.repository.MessageRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ChatService {

    private final MessageRepository messageRepository;
    private final ChatCacheService chatCacheService;

    public List<Message> getChat(String chatId) {
        List<Message> cached = chatCacheService.getCachedChat(chatId);
        if (cached != null) {
            return cached;
        }

        List<Message> messages = messageRepository.findByChatId(chatId);

        chatCacheService.cacheChat(chatId, messages);
        return messages;
    }

    public Message sendMessage(Message message) {
        Message saved = messageRepository.save(message);
        chatCacheService.evictChatCache(message.getChatId());
        return saved;
    }

    public String createChat(String token, List<String> userIds) {
        return token;
    }

    public List<?> getUserChats(String token) {
        return List.of();
    }

    public void editMessage(String token, String id, MessageRequest req) {
    }

    public void sendMessage(String token, MessageRequest req) {
    }

    public void deleteMessage(String token, String id) {
    }

    public void markAsRead(String token, String chatId) {
    }
}