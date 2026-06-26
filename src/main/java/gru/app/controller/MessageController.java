package gru.app.controller;

import gru.app.dto.SendMessageRequest;
import gru.app.model.Message;
import gru.app.service.MessageService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequiredArgsConstructor
@RequestMapping
public class MessageController {

    private final MessageService messageService;

    @PostMapping("/messages")
    public Message send(
            Authentication auth,
            @RequestBody SendMessageRequest request
    ) {
        return messageService.send(
                auth.getName(),
                request
        );
    }

    @GetMapping("/chats/{chatId}/messages")
    public List<Message> messages(
            @PathVariable String chatId
    ) {
        return messageService.findByChatId(chatId);
    }
}