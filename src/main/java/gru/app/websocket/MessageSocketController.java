package gru.app.websocket;

import org.springframework.messaging.MessagingException;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.stereotype.Controller;

/**
 * Legacy STOMP plaintext send endpoint.
 *
 * Direct-chat production messaging is E2EE-only. Keeping the historical
 * mapping as an explicit fail-closed endpoint prevents an old or custom client
 * from bypassing the encrypted REST message contract through /app/send.
 */
@Controller
public class MessageSocketController {

    @MessageMapping("/send")
    public void send() {
        throw new MessagingException(
                "Legacy plaintext STOMP message send is disabled; use the E2EE message transport"
        );
    }
}
