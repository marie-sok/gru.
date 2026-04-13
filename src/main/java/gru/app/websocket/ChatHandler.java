package gru.app.websocket;

import com.fasterxml.jackson.databind.ObjectMapper;
import gru.app.model.Message;
import gru.app.model.MessageType;
import gru.app.service.MessageService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.*;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Component
@RequiredArgsConstructor
public class ChatHandler extends WebSocketHandler {

    private final MessageService messageService;
    private final ObjectMapper mapper = new ObjectMapper();

    private final Map<String, WebSocketSession> sessions = new ConcurrentHashMap<>();

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        sessions.put(session.getId(), session);
    }

    @Override
    public void handleMessage(WebSocketSession session, WebSocketMessage<?> message) throws Exception {

        Map<String, Object> payload = mapper.readValue(message.getPayload().toString(), Map.class);

        String sender = (String) payload.get("senderId");
        String receiver = (String) payload.get("receiverId");
        String content = (String) payload.get("content");

        Message msg = messageService.send(sender, receiver, content, MessageType.TEXT);

        String json = mapper.writeValueAsString(msg);

        sessions.values().forEach(s -> {
            try {
                s.sendMessage(new TextMessage(json));
            } catch (Exception ignored) {}
        });
    }

    @Override public void handleTransportError(WebSocketSession s, Throwable e) {}
    @Override public void afterConnectionClosed(WebSocketSession s, CloseStatus c) {}
    @Override public boolean supportsPartialMessages() { return false; }
}