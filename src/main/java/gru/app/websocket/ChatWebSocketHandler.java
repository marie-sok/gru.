package gru.app.websocket;

import com.fasterxml.jackson.databind.ObjectMapper;
import gru.app.model.Message;
import gru.app.service.MessageService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.*;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Component
@RequiredArgsConstructor
public class ChatWebSocketHandler extends WebSocketHandler {

    private final MessageService messageService;
    private final ObjectMapper mapper = new ObjectMapper();

    private final Map<String, WebSocketSession> sessions = new ConcurrentHashMap<>();

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        String userId = session.getPrincipal().getName();
        sessions.put(userId, session);
    }

    @Override
    public void handleMessage(WebSocketSession session, WebSocketMessage<?> msg) throws Exception {

        var data = mapper.readValue(msg.getPayload().toString(), Map.class);

        String type = (String) data.get("type");

        switch (type) {

            case "MESSAGE" -> {
                String chatId = (String) data.get("chatId");
                String senderId = (String) data.get("senderId");
                String receiverId = (String) data.get("receiverId");
                String content = (String) data.get("content");

                Message saved = messageService.save(chatId, senderId, receiverId, content);

                send(receiverId, saved);
                send(senderId, saved);
            }

            case "READ" -> {
                String messageId = (String) data.get("messageId");
                messageService.markRead(messageId);
            }
        }
    }

    private void send(String userId, Object payload) throws Exception {
        WebSocketSession s = sessions.get(userId);
        if (s != null && s.isOpen()) {
            s.sendMessage(new TextMessage(mapper.writeValueAsString(payload)));
        }
    }

    @Override public void handleTransportError(WebSocketSession session, Throwable exception) {}
    @Override public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {}
    @Override public boolean supportsPartialMessages() { return false; }
}