package gru.app.websocket;

import gru.app.model.Chat;
import gru.app.model.User;
import gru.app.repository.ChatRepository;
import gru.app.repository.UserRepository;
import gru.app.service.PresenceRegistry;
import lombok.RequiredArgsConstructor;
import org.springframework.context.event.EventListener;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.messaging.SessionConnectEvent;
import org.springframework.web.socket.messaging.SessionDisconnectEvent;

import java.security.Principal;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Component
@RequiredArgsConstructor
public class PresenceEventListener {

    private static final String PRIVATE_PRESENCE_QUEUE = "/queue/presence";

    private final PresenceRegistry presenceRegistry;
    private final SimpMessagingTemplate messagingTemplate;
    private final ChatRepository chatRepository;
    private final UserRepository userRepository;

    @EventListener
    public void onConnect(SessionConnectEvent event) {
        StompHeaderAccessor accessor = StompHeaderAccessor.wrap(event.getMessage());
        Principal principal = accessor.getUser();
        String sessionId = accessor.getSessionId();

        if (principal == null || sessionId == null) {
            return;
        }

        String userId = principal.getName();
        if (presenceRegistry.connect(userId, sessionId)) {
            publishToAuthorizedPeers(userId, true);
        }
    }

    @EventListener
    public void onDisconnect(SessionDisconnectEvent event) {
        PresenceRegistry.DisconnectResult result = presenceRegistry.disconnect(event.getSessionId());

        if (result.userId() != null && result.becameOffline()) {
            publishToAuthorizedPeers(result.userId(), false);
        }
    }

    private void publishToAuthorizedPeers(String userId, boolean online) {
        if (userId == null || userId.isBlank()) {
            return;
        }

        User subject = userRepository.findById(userId).orElse(null);
        if (subject == null) {
            return;
        }

        List<Chat> chats = chatRepository.findByParticipantsContains(userId);
        if (chats == null || chats.isEmpty()) {
            return;
        }

        Set<String> candidatePeerIds = new HashSet<>();
        for (Chat chat : chats) {
            if (chat.getParticipants() == null) continue;
            for (String participantId : chat.getParticipants()) {
                if (participantId != null
                        && !participantId.isBlank()
                        && !participantId.equals(userId)) {
                    candidatePeerIds.add(participantId);
                }
            }
        }

        if (candidatePeerIds.isEmpty()) {
            return;
        }

        Map<String, Object> payload = Map.of(
                "userId", userId,
                "online", online
        );

        for (User peer : userRepository.findAllById(candidatePeerIds)) {
            if (peer == null || peer.getId() == null) continue;
            if (isBlocked(subject, peer.getId()) || isBlocked(peer, subject.getId())) continue;

            messagingTemplate.convertAndSendToUser(
                    peer.getId(),
                    PRIVATE_PRESENCE_QUEUE,
                    payload
            );
        }
    }

    private boolean isBlocked(User user, String targetUserId) {
        return user.getBlockedUserIds() != null
                && user.getBlockedUserIds().contains(targetUserId);
    }
}
