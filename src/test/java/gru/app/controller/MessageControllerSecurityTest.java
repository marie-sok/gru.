package gru.app.controller;

import gru.app.dto.EditMessageRequest;
import gru.app.dto.SendMessageRequest;
import gru.app.service.MessageService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.web.server.ResponseStatusException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;

class MessageControllerSecurityTest {

    private MessageController controller;
    private Authentication authentication;

    @BeforeEach
    void setUp() {
        controller = new MessageController(
                mock(MessageService.class),
                mock(SimpMessagingTemplate.class)
        );
        authentication = mock(Authentication.class);
    }

    @Test
    void legacyPlaintextSendReturnsUpgradeRequired() {
        assertThatThrownBy(() -> controller.send(authentication, new SendMessageRequest()))
                .isInstanceOf(ResponseStatusException.class)
                .satisfies(error -> assertThat(((ResponseStatusException) error).getStatusCode().value())
                        .isEqualTo(426));
    }

    @Test
    void legacyPlaintextEditReturnsUpgradeRequired() {
        assertThatThrownBy(() -> controller.editMessage(
                authentication,
                "message-1",
                new EditMessageRequest()
        ))
                .isInstanceOf(ResponseStatusException.class)
                .satisfies(error -> assertThat(((ResponseStatusException) error).getStatusCode().value())
                        .isEqualTo(426));
    }
}
