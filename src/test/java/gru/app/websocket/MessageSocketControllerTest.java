package gru.app.websocket;

import org.junit.jupiter.api.Test;
import org.springframework.messaging.MessagingException;

import static org.assertj.core.api.Assertions.assertThatThrownBy;

class MessageSocketControllerTest {

    @Test
    void legacyPlaintextSendIsDisabled() {
        MessageSocketController controller = new MessageSocketController();

        assertThatThrownBy(controller::send)
                .isInstanceOf(MessagingException.class)
                .hasMessageContaining("plaintext STOMP message send is disabled");
    }
}
