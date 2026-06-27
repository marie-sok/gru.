package gru.app.websocket;

import gru.app.dto.SendMessageRequest;
import gru.app.model.Message;
import gru.app.service.MessageService;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Controller;

@Controller
@RequiredArgsConstructor
public class MessageSocketController {

    private final MessageService messageService;
    private final SimpMessagingTemplate messagingTemplate;

    @MessageMapping("/send")
    public void send(
            Authentication authentication,
            SendMessageRequest request
    ) {

        Message message = messageService.send(
                authentication.getName(),
                request
        );

        messagingTemplate.convertAndSend(
                "/topic/chat/" + request.getChatId(),
                message
        );
    }
}