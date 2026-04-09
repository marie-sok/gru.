package functional.unique.creator.kerry.websocket;

import functional.unique.creator.kerry.model.Message;
import functional.unique.creator.kerry.service.MessageService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.web.socket.*;
import org.springframework.web.socket.handler.TextWebSocketHandler;
import java.util.Map;
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
        Long userId = Long.parseLong(session.getUri().getQuery().split("=")[1]);
        sessions.put(userId, session);
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception {
        Message msg = mapper.readValue(message.getPayload(), Message.class);
        messageService.save(msg);

        WebSocketSession receiverSession = sessions.get(msg.getReceiverId());
        if (receiverSession != null) {
            receiverSession.sendMessage(new TextMessage(mapper.writeValueAsString(msg)));
        }
    }
}