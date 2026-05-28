package gru.app.websocket;

import gru.app.model.Message;
import gru.app.service.MessageService;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.NonNull;
import org.springframework.web.socket.*;
import org.springframework.web.socket.handler.TextWebSocketHandler;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.ConcurrentHashMap;

public class WebSocketController extends TextWebSocketHandler {

    private final ObjectMapper mapper = new ObjectMapper();
    private final Map<Long, WebSocketSession> sessions = new ConcurrentHashMap<>();
    private final MessageService messageService; // TODO: inject repo

    public WebSocketController(MessageService messageService) {
        this.messageService = messageService;
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) throws Exception {
        Long userId = Long.parseLong(Objects.requireNonNull(session.getUri()).getQuery().split("=")[1]);
        sessions.put(userId, session);
    }

    @Override
    protected void handleTextMessage(@NonNull WebSocketSession session, TextMessage message) throws Exception {
        Message msg = mapper.readValue(message.getPayload(), Message.class);
        messageService.save(msg);

        WebSocketSession receiverSession = sessions.get(msg.getReceiverId());
        if (receiverSession != null) {
            receiverSession.sendMessage(new TextMessage(mapper.writeValueAsString(msg)));
        }
    }
}