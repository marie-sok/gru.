package gru.app.controller;

import gru.app.dto.MessageResponse;
import gru.app.service.ChatService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/chat")
@RequiredArgsConstructor
public class ChatController {

    private final ChatService chatService;

    @GetMapping("/{chatId}/messages")
    public List<MessageResponse> getMessages(
            @PathVariable String chatId
    ) {
        return chatService.getMessages(chatId);
    }
}