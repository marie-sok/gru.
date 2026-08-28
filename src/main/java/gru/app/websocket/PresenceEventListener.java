package gru.app.websocket;

import gru.app.service.PresenceRegistry;
import lombok.RequiredArgsConstructor;
import org.springframework.context.event.EventListener;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.messaging.SessionConnectEvent;
import org.springframework.web.socket.messaging.SessionDisconnectEvent;

import java.security.Principal;
import java.util.Map;

@Component
@RequiredArgsConstructor
public class PresenceEventListener {

    private final PresenceRegistry presenceRegistry;
    private final SimpMessagingTemplate messagingTemplate;

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
            publish(userId, true);
        }
    }

    @EventListener
    public void onDisconnect(SessionDisconnectEvent event) {
        PresenceRegistry.DisconnectResult result = presenceRegistry.disconnect(event.getSessionId());

        if (result.userId() != null && result.becameOffline()) {
            publish(result.userId(), false);
        }
    }

    private void publish(String userId, boolean online) {
        messagingTemplate.convertAndSend(
                "/topic/presence",
                Map.of(
                        "userId", userId,
                        "online", online
                )
        );
    }
}
