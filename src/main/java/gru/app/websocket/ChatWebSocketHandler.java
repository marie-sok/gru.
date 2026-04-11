package gru.app.websocket;

import com.fasterxml.jackson.databind.ObjectMapper;
import gru.app.repository.ChatRepository;
import gru.app.security.JwtUtil;
import gru.app.service.MessageService;
import gru.app.service.PresenceService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Component
@RequiredArgsConstructor
public class ChatWebSocketHandler {

    private final JwtUtil jwtUtil;
    private final MessageService messageService;
    private final PresenceService presenceService;
    private final ChatRepository chatRepository;

    private final ObjectMapper mapper = new ObjectMapper();

    private final Map<String, WebSocketSession> sessions = new ConcurrentHashMap<>();

    private String getToken(WebSocketSession session) {
        String query = session.getUri().getQuery();

        if (query == null) return null;

        for (String param : query.split("&")) {
            if (param.startsWith("token=")) {
                return param.substring(6);
            }
        }

        return null;
    }

}