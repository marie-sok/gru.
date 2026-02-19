package functional.unique.creator.kerry.websocket;

import com.fasterxml.jackson.databind.ObjectMapper;
import functional.unique.creator.kerry.model.Message;
import functional.unique.creator.kerry.model.Users;
import functional.unique.creator.kerry.repository.MessageRepository;
import functional.unique.creator.kerry.repository.UserRepository;
import functional.unique.creator.kerry.security.JwtUtil;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jws;
import io.jsonwebtoken.JwtException;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.*;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.time.LocalDateTime;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.List;

@Component
public class ChatHandler extends TextWebSocketHandler {

    private final CopyOnWriteArrayList<WebSocketSession> sessions = new CopyOnWriteArrayList<>();
    private final MessageRepository messageRepo;
    private final UserRepository userRepo;
    private final JwtUtil jwtUtil;
    private final ObjectMapper mapper = new ObjectMapper();

    public ChatHandler(MessageRepository messageRepo,
                       UserRepository userRepo,
                       JwtUtil jwtUtil) {
        this.messageRepo = messageRepo;
        this.userRepo = userRepo;
        this.jwtUtil = jwtUtil;
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) throws Exception {
        String token = getTokenFromSession(session);
        Users user = validateAndGetUser(token);
        if (user == null) {
            session.close(CloseStatus.NOT_ACCEPTABLE.withReason("Invalid or missing JWT token"));
            return;
        }

        sessions.add(session);
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage textMessage) throws Exception {
        Users sender = validateAndGetUser(getTokenFromSession(session));
        if (sender == null) {
            session.close(CloseStatus.NOT_ACCEPTABLE.withReason("Invalid JWT token"));
            return;
        }

        Message msg = mapper.readValue(textMessage.getPayload(), Message.class);
        msg.setSenderId(sender.getId());
        msg.setTimestamp(LocalDateTime.now());

        Users receiver = userRepo.findById(msg.getReceiverId()).orElse(null);
        if (receiver == null) return;

        messageRepo.save(msg);

        String json = mapper.writeValueAsString(msg);

        for (WebSocketSession s : sessions) {
            if (s.isOpen()) {
                Users u = validateAndGetUser(getTokenFromSession(s));
                if (u != null && (u.getId().equals(msg.getReceiverId()) || u.getId().equals(sender.getId()))) {
                    s.sendMessage(new TextMessage(json));
                }
            }
        }
    }

    public List<Message> getHistory(Long userId1, Long userId2) {
        return messageRepo.findTop50BySenderIdAndReceiverIdOrSenderIdAndReceiverIdOrderByTimestampAsc(
                userId1, userId2, userId2, userId1
        );
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        sessions.remove(session);
    }

    private String getTokenFromSession(WebSocketSession session) {
        String query = session.getUri().getQuery();
        if (query != null && query.startsWith("token=")) {
            return query.substring(6);
        }
        return null;
    }

    private Users validateAndGetUser(String token) {
        try {
            if (token == null) return null;
            Jws<Claims> claims = jwtUtil.validateToken(token);
            String phone = claims.getBody().getSubject();
            return userRepo.findByPhone(phone).orElse(null);
        } catch (JwtException e) {
            return null;
        }
    }
}
