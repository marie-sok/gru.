package functional.unique.creator.kerry.controller;

import functional.unique.creator.kerry.dto.ChatMessage;
import functional.unique.creator.kerry.model.Message;
import functional.unique.creator.kerry.service.MessageService;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Controller;

@Controller
public class ChatController {

    private final SimpMessagingTemplate template;
    private final MessageService messageService;

    public ChatController(SimpMessagingTemplate template,
                          MessageService messageService) {
        this.template = template;
        this.messageService = messageService;
    }

    @MessageMapping("/chat")
    public void send(ChatMessage msg) {

        Message saved = messageService.save(
                msg.getSenderId(),
                msg.getReceiverId(),
                msg.getContent()
        );

        template.convertAndSendToUser(
                msg.getReceiverId().toString(),
                "/queue/messages",
                saved
        );
    }
}