package gru.app.websocket;

import com.fasterxml.jackson.databind.ObjectMapper;
import gru.app.model.Message;
import gru.app.security.JwtUtil;
import gru.app.service.MessageService;
import gru.app.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.WebSocketMessage;


import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Component
@RequiredArgsConstructor
public abstract class WebSocketHandler extends TextWebSocketHandler {

    private JwtUtil jwtUtil;
    private UserService userService;
    private MessageService messageService;
    private ObjectMapper objectMapper = new ObjectMapper();

    private Map<String, WebSocketSession> sessions = new ConcurrentHashMap<>();

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {

        String query = session.getUri().getQuery();
        String token = parseQuery(query).get("token");

        if (token == null || !jwtUtil.isValid(token)) {
            session.close(CloseStatus.NOT_ACCEPTABLE);
            return;
        }

        String userId = jwtUtil.extractUserId(token);

        sessions.put(userId, session);
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception {

        Map<String, Object> payload =
                objectMapper.readValue(message.getPayload(), Map.class);

        String type = (String) payload.get("type");
        String senderId = (String) payload.get("senderId");
        String receiverId = (String) payload.get("receiverId");

        switch (type) {

            case "MESSAGE" -> {

                String content = (String) payload.get("content");

                Message msg = messageService.sendInternal(
                        senderId,
                        receiverId,
                        content
                );

                sendToUser(receiverId, msg);
                sendToUser(senderId, msg);
            }

            case "TYPING" -> {
                sendToUser(receiverId,
                        Map.of("type", "TYPING", "senderId", senderId));
            }

            case "READ" -> {
                String messageId = (String) payload.get("messageId");

                messageService.markAsRead(messageId);

                sendToUser(receiverId,
                        Map.of("type", "READ", "messageId", messageId));
            }
        }
    }

    public abstract void handleMessage(WebSocketSession session, WebSocketMessage<?> message) throws Exception;

    private void sendToUser(String userId, Object data) throws Exception {

        WebSocketSession session = sessions.get(userId);

        if (session != null && session.isOpen()) {
            session.sendMessage(
                    new TextMessage(objectMapper.writeValueAsString(data))
            );
        }
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        sessions.values().remove(session);
    }

    private Map<String, String> parseQuery(String query) {

        Map<String, String> map = new ConcurrentHashMap<>();

        if (query == null) return map;

        for (String param : query.split("&")) {
            String[] kv = param.split("=");
            if (kv.length == 2) {
                map.put(kv[0], kv[1]);
            }
        }

        return map;
    }

    public abstract void handleTransportError(WebSocketSession session, Throwable exception);

    public abstract boolean supportsPartialMessages();
}