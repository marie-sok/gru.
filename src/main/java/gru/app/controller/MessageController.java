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
            Authentication authentication,
            @RequestBody SendMessageRequest request
    ) {

        return messageService.send(
                authentication.getName(),
                request
        );
    }

    @GetMapping("/chats/{chatId}/messages")
    public List<Message> getMessages(
            @PathVariable String chatId
    ) {

        return messageService.getMessages(chatId);
    }
}