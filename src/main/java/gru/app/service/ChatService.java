package gru.app.service;

import gru.app.dto.CreateChatRequest;
import gru.app.model.Chat;
import gru.app.repository.ChatRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;

@Service
@RequiredArgsConstructor
public class ChatService {

    private final ChatRepository chatRepository;

    public Chat createChat(
            String currentUserId,
            CreateChatRequest request
    ) {

        Chat chat = new Chat();

        chat.setParticipants(
                List.of(
                        currentUserId,
                        request.getUserId()
                )
        );

        chat.setCreatedAt(Instant.now());

        return chatRepository.save(chat);
    }

    public List<Chat> getMyChats(String userId) {

        return chatRepository.findByParticipantsContains(userId);
    }
}