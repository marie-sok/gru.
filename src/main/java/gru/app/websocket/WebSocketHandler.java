package gru.app.websocket;

import com.fasterxml.jackson.databind.ObjectMapper;
import gru.app.model.Message;
import gru.app.model.User;
import gru.app.security.JwtUtil;
import gru.app.service.MessageService;
import gru.app.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.*;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Component
@RequiredArgsConstructor
public class WebSocketHandler implements org.springframework.web.socket.WebSocketHandler {

    private final JwtUtil jwtUtil;
    private final UserService userService;
    private final MessageService messageService;
    private final ObjectMapper objectMapper = new ObjectMapper();

    private final Map<Long, WebSocketSession> sessions = new ConcurrentHashMap<>();

    @Override
    public void afterConnectionEstablished(WebSocketSession session) throws Exception {
        String query = session.getUri().getQuery();
        Map<String, String> params = parseQuery(query);
        String token = params.get("token");

        if (token == null || jwtUtil.isTokenExpired(token)) {
            session.close(CloseStatus.NOT_ACCEPTABLE);
            return;
        }

        String phone = jwtUtil.getPhoneFromToken(token);
        User user = userService.findByPhone(phone);
        if (user == null) {
            session.close(CloseStatus.NOT_ACCEPTABLE);
            return;
        }

        sessions.put(Long.valueOf(user.getId()), session);
    }

    @Override
    public void handleMessage(WebSocketSession session, WebSocketMessage<?> message) throws Exception {
        Map<String, Object> payload = objectMapper.readValue(message.getPayload().toString(), Map.class);
        String type = (String) payload.get("type");
        Long senderId = ((Number) payload.get("senderId")).longValue();
        Long receiverId = ((Number) payload.get("receiverId")).longValue();

        switch (type) {
            case "MESSAGE" -> {
                String content = (String) payload.get("content");
                String contentType = (String) payload.get("contentType");
                Message msg = new Message();
                messageService.saveMessage(msg);
                sendToUser(receiverId, msg);
                sendToUser(senderId, msg); // показать себе
            }
            case "TYPING" -> sendTyping(receiverId, senderId);
            case "READ" -> {
                Long msgId = ((Number) payload.get("messageId")).longValue();
                messageService.markRead(msgId);
                sendRead(receiverId, msgId, senderId);
            }
        }
    }

    private void sendToUser(Long userId, Object msg) throws Exception {
        WebSocketSession s = sessions.get(userId);
        if (s != null && s.isOpen()) {
            s.sendMessage(new TextMessage(objectMapper.writeValueAsString(msg)));
        }
    }

    private void sendTyping(Long receiverId, Long senderId) throws Exception {
        Map<String, Object> typing = Map.of("type", "TYPING", "senderId", senderId);
        sendToUser(receiverId, typing);
    }

    private void sendRead(Long receiverId, Long messageId, Long senderId) throws Exception {
        Map<String, Object> read = Map.of("type", "READ", "messageId", messageId, "senderId", senderId);
        sendToUser(receiverId, read);
    }

    @Override
    public void handleTransportError(WebSocketSession session, Throwable exception) throws Exception {
        session.close(CloseStatus.SERVER_ERROR);
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus closeStatus) throws Exception {
        sessions.values().remove(session);
    }

    @Override
    public boolean supportsPartialMessages() { return false; }

    private Map<String, String> parseQuery(String query) {
        Map<String, String> map = new HashMap<>();
        if (query != null) {
            for (String param : query.split("&")) {
                String[] kv = param.split("=");
                if (kv.length == 2) map.put(kv[0], kv[1]);
            }
        }
        return map;
    }
}