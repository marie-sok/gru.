package gru.app.websocket;

import gru.app.model.Chat;
import gru.app.repository.ChatRepository;
import gru.app.service.JwtService;
import lombok.RequiredArgsConstructor;
import org.springframework.lang.NonNull;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.MessagingException;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.stereotype.Component;

import java.security.Principal;

@Component
@RequiredArgsConstructor
public class JwtChannelInterceptor implements ChannelInterceptor {

    private static final String PRIVATE_PRESENCE_QUEUE = "/user/queue/presence";
    private static final String CHAT_TOPIC_PREFIX = "/topic/chat/";
    private static final String TYPING_SUFFIX = "/typing";

    private final JwtService jwtService;
    private final ChatRepository chatRepository;

    @Override
    public Message<?> preSend(
            @NonNull Message<?> message,
            @NonNull MessageChannel channel
    ) {
        StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(
                message,
                StompHeaderAccessor.class
        );

        if (accessor == null || accessor.getCommand() == null) {
            return message;
        }

        StompCommand command = accessor.getCommand();

        if (StompCommand.CONNECT.equals(command)) {
            String userId = authenticatedUserFromBearer(accessor);
            accessor.setUser(() -> userId);
            return message;
        }

        if (StompCommand.SUBSCRIBE.equals(command)) {
            String userId = requireAuthenticatedUser(accessor);
            authorizeSubscription(userId, accessor.getDestination());
            return message;
        }

        if (StompCommand.SEND.equals(command)
                || StompCommand.UNSUBSCRIBE.equals(command)
                || StompCommand.DISCONNECT.equals(command)) {
            requireAuthenticatedUser(accessor);
        }

        return message;
    }

    private String requireAuthenticatedUser(StompHeaderAccessor accessor) {
        Principal principal = accessor.getUser();
        if (principal != null && principal.getName() != null && !principal.getName().isBlank()) {
            return principal.getName();
        }

        // Some STOMP clients repeat Authorization on SUBSCRIBE/SEND. Validate
        // the frame token directly instead of mutating immutable headers.
        return authenticatedUserFromBearer(accessor);
    }

    private String authenticatedUserFromBearer(StompHeaderAccessor accessor) {
        String token = bearerToken(accessor);
        if (!jwtService.isValid(token)) {
            throw new MessagingException("Invalid STOMP authorization token");
        }

        String userId = jwtService.extractUserId(token);
        if (userId == null || userId.isBlank()) {
            throw new MessagingException("Invalid STOMP principal");
        }
        return userId;
    }

    private String bearerToken(StompHeaderAccessor accessor) {
        String header = accessor.getFirstNativeHeader("Authorization");
        if (header == null || !header.startsWith("Bearer ")) {
            throw new MessagingException("Missing STOMP authorization token");
        }

        String token = header.substring(7).trim();
        if (token.isEmpty()) {
            throw new MessagingException("Missing STOMP authorization token");
        }
        return token;
    }

    private void authorizeSubscription(String userId, String destination) {
        if (destination == null || destination.isBlank()) {
            throw new MessagingException("Missing STOMP subscription destination");
        }

        // Spring resolves /user destinations to a session-specific broker queue.
        // A client cannot select another user's queue through this destination.
        if (PRIVATE_PRESENCE_QUEUE.equals(destination)) {
            return;
        }

        String chatId = extractChatId(destination);
        if (chatId == null) {
            // This also rejects the old global /topic/presence metadata feed.
            throw new MessagingException("STOMP subscription destination is not allowed");
        }

        Chat chat = chatRepository.findById(chatId)
                .orElseThrow(() -> new MessagingException("Chat subscription is not allowed"));

        if (chat.getParticipants() == null || !chat.getParticipants().contains(userId)) {
            throw new MessagingException("Chat subscription is not allowed");
        }
    }

    private String extractChatId(String destination) {
        if (!destination.startsWith(CHAT_TOPIC_PREFIX)) {
            return null;
        }

        String remainder = destination.substring(CHAT_TOPIC_PREFIX.length());
        if (remainder.endsWith(TYPING_SUFFIX)) {
            remainder = remainder.substring(0, remainder.length() - TYPING_SUFFIX.length());
        }

        if (remainder.isBlank() || remainder.contains("/")) {
            return null;
        }
        return remainder;
    }
}
