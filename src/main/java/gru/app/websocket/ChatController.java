package gru.app.websocket;

import gru.app.dto.ChatMessage;
import gru.app.model.Message;
import gru.app.service.MessageService;
import lombok.RequiredArgsConstructor;
import lombok.Setter;
import org.springframework.messaging.handler.annotation.*;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Controller;

@Setter
@Controller
@RequiredArgsConstructor
public class ChatController {

    private  MessageService messageService;
    private  SimpMessagingTemplate template;

    @MessageMapping("/chat.send")
    public void send(@Payload ChatMessage msg) {

        Message saved = messageService.send(
                msg.getSenderId(),
                msg.getReceiverId(),
                msg.getContent()
        );

        template.convertAndSend(
                "/topic/chat/" + msg.getReceiverId(),
                saved
        );
    }

}