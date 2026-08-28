package gru.app.service;

import gru.app.dto.ChatParticipantResponse;
import gru.app.dto.ChatResponse;
import gru.app.dto.CreateChatRequest;
import gru.app.model.Chat;
import gru.app.model.User;
import gru.app.repository.ChatRepository;
import gru.app.repository.MessageRepository;
import gru.app.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class ChatService {

    private final ChatRepository chatRepository;

    private final UserRepository userRepository;

    private final MessageRepository messageRepository;

    private final MediaStorageService mediaStorageService;

    // MARK: - Create Chat

    public ChatResponse createChat(
            String currentUserId,
            CreateChatRequest request
    ) {

        String otherUserId =
                request.getUserId();

        if (otherUserId == null ||
                otherUserId.isBlank()) {

            throw new IllegalArgumentException(
                    "User ID is required"
            );
        }

        if (currentUserId.equals(otherUserId)) {

            throw new IllegalArgumentException(
                    "Cannot create chat with yourself"
            );
        }

        User currentUser =
                userRepository.findById(
                        currentUserId
                ).orElseThrow(
                        () ->
                                new IllegalArgumentException(
                                        "Current user not found"
                                )
                );

        User otherUser =
                userRepository.findById(
                        otherUserId
                ).orElseThrow(
                        () ->
                                new IllegalArgumentException(
                                        "User not found"
                                )
                );

        if (isBlocked(currentUser, otherUserId) || isBlocked(otherUser, currentUserId)) {
            throw new IllegalArgumentException(
                    "Chat cannot be created because one participant has blocked the other"
            );
        }

        Chat chat =
                new Chat();

        chat.setParticipants(
                List.of(
                        currentUserId,
                        otherUserId
                )
        );

        chat.setCreatedAt(
                Instant.now()
        );

        Chat savedChat =
                chatRepository.save(
                        chat
                );

        return new ChatResponse(
                savedChat.getId(),
                List.of(
                        toParticipant(
                                currentUser
                        ),
                        toParticipant(
                                otherUser
                        )
                ),
                savedChat.getCreatedAt()
        );
    }

    // MARK: - My Chats

    public List<ChatResponse> getMyChats(
            String userId
    ) {

        List<Chat> chats =
                chatRepository
                        .findByParticipantsContains(
                                userId
                        );

        if (chats.isEmpty()) {

            return List.of();
        }

        Set<String> participantIds =
                new HashSet<>();

        for (Chat chat : chats) {

            if (chat.getParticipants() != null) {

                participantIds.addAll(
                        chat.getParticipants()
                );
            }
        }

        Iterable<User> users =
                userRepository.findAllById(
                        participantIds
                );

        Map<String, User> usersById =
                new HashMap<>();

        for (User user : users) {

            usersById.put(
                    user.getId(),
                    user
            );
        }

        List<ChatResponse> result =
                new ArrayList<>();

        for (Chat chat : chats) {

            List<ChatParticipantResponse>
                    participants =
                    new ArrayList<>();

            if (chat.getParticipants() != null) {

                for (String participantId :
                        chat.getParticipants()) {

                    User user =
                            usersById.get(
                                    participantId
                            );

                    if (user != null) {

                        participants.add(
                                toParticipant(
                                        user
                                )
                        );
                    }
                }
            }

            result.add(
                    new ChatResponse(
                            chat.getId(),
                            participants,
                            chat.getCreatedAt()
                    )
            );
        }

        return result;
    }


    // MARK: - Delete Chat For Everyone

    public List<String> deleteChatForEveryone(
            String userId,
            String chatId
    ) {
        Chat chat = chatRepository.findById(chatId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Chat not found"));

        if (chat.getParticipants() == null || !chat.getParticipants().contains(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Not a chat participant");
        }

        var messages = messageRepository.findByChatIdOrderByCreatedAtAsc(chatId);
        for (var message : messages) {
            if (message.getAttachment() != null) {
                mediaStorageService.deleteByRemoteURL(message.getAttachment().getRemoteURL());
            }
        }

        if (!messages.isEmpty()) {
            messageRepository.deleteAll(messages);
        }

        List<String> participants = chat.getParticipants() == null
                ? List.of()
                : List.copyOf(chat.getParticipants());

        chatRepository.delete(chat);
        return participants;
    }

    private boolean isBlocked(User user, String targetUserId) {
        return user.getBlockedUserIds() != null && user.getBlockedUserIds().contains(targetUserId);
    }

    // MARK: - Participant DTO

    private ChatParticipantResponse toParticipant(
            User user
    ) {

        String nickname =
                user.getNickname();

        if (nickname == null ||
                nickname.isBlank()) {

            nickname =
                    "Пользователь";
        }

        return new ChatParticipantResponse(
                user.getId(),
                nickname
        );
    }
}