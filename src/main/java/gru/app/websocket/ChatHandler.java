package gru.app.websocket;


import lombok.NonNull;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.util.HashSet;
import java.util.Set;

public class ChatHandler extends TextWebSocketHandler {

    private static final Set<WebSocketSession> sessions = new HashSet<>();

    @Override
    public void afterConnectionEstablished(@NonNull WebSocketSession session) {
        sessions.add(session);
        System.out.println("Connected: " + session.getId());
    }

    @Override
    protected void handleTextMessage(@NonNull WebSocketSession session, @NonNull TextMessage message) throws Exception {
        for (WebSocketSession s : sessions) {
            if (s.isOpen()) {
                s.sendMessage(message);
            }
        }
    }

    @Override
    public void afterConnectionClosed(@NonNull WebSocketSession session, @NonNull CloseStatus status) {
        sessions.remove(session);
        System.out.println("Disconnected: " + session.getId());
    }
}