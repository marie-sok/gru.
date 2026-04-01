package functional.unique.creator.kerry.websocket;

import functional.unique.creator.kerry.dto.ChatMessage;
import functional.unique.creator.kerry.model.Message;
import functional.unique.creator.kerry.service.MessageService;
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