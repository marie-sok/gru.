package gru.app.websocket;

import gru.app.model.Chat;
import gru.app.repository.ChatRepository;
import gru.app.service.JwtService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.MessagingException;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.MessageBuilder;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class JwtChannelInterceptorTest {

    private JwtService jwtService;
    private ChatRepository chatRepository;
    private JwtChannelInterceptor interceptor;
    private MessageChannel channel;

    @BeforeEach
    void setUp() {
        jwtService = mock(JwtService.class);
        chatRepository = mock(ChatRepository.class);
        interceptor = new JwtChannelInterceptor(jwtService, chatRepository);
        channel = mock(MessageChannel.class);

        when(jwtService.isValid("valid-token")).thenReturn(true);
        when(jwtService.extractUserId("valid-token")).thenReturn("user-a");
    }

    @Test
    void allowsParticipantToSubscribeToChatTopic() {
        Chat chat = chat("chat-1", List.of("user-a", "user-b"));
        when(chatRepository.findById("chat-1")).thenReturn(Optional.of(chat));

        Message<byte[]> message = frame(StompCommand.SUBSCRIBE, "/topic/chat/chat-1");

        assertThatCode(() -> interceptor.preSend(message, channel))
                .doesNotThrowAnyException();
    }

    @Test
    void allowsParticipantToSubscribeToTypingTopic() {
        Chat chat = chat("chat-1", List.of("user-a", "user-b"));
        when(chatRepository.findById("chat-1")).thenReturn(Optional.of(chat));

        Message<byte[]> message = frame(StompCommand.SUBSCRIBE, "/topic/chat/chat-1/typing");

        assertThatCode(() -> interceptor.preSend(message, channel))
                .doesNotThrowAnyException();
    }

    @Test
    void rejectsNonParticipantFromChatTopic() {
        Chat chat = chat("chat-1", List.of("user-b", "user-c"));
        when(chatRepository.findById("chat-1")).thenReturn(Optional.of(chat));

        Message<byte[]> message = frame(StompCommand.SUBSCRIBE, "/topic/chat/chat-1");

        assertThatThrownBy(() -> interceptor.preSend(message, channel))
                .isInstanceOf(MessagingException.class)
                .hasMessageContaining("not allowed");
    }

    @Test
    void rejectsUnknownTopicEvenWithValidJwt() {
        Message<byte[]> message = frame(StompCommand.SUBSCRIBE, "/topic/admin");

        assertThatThrownBy(() -> interceptor.preSend(message, channel))
                .isInstanceOf(MessagingException.class)
                .hasMessageContaining("not allowed");
    }

    @Test
    void allowsAuthenticatedPresenceSubscription() {
        Message<byte[]> message = frame(StompCommand.SUBSCRIBE, "/topic/presence");

        assertThatCode(() -> interceptor.preSend(message, channel))
                .doesNotThrowAnyException();
    }

    private Message<byte[]> frame(StompCommand command, String destination) {
        StompHeaderAccessor accessor = StompHeaderAccessor.create(command);
        accessor.setDestination(destination);
        accessor.addNativeHeader("Authorization", "Bearer valid-token");
        return MessageBuilder.createMessage(new byte[0], accessor.getMessageHeaders());
    }

    private Chat chat(String id, List<String> participants) {
        Chat chat = new Chat();
        chat.setId(id);
        chat.setParticipants(participants);
        return chat;
    }
}
