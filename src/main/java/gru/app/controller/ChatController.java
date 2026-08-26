package gru.app.controller;

import gru.app.dto.ChatResponse;
import gru.app.dto.CreateChatRequest;
import gru.app.service.ChatService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/chats")
@RequiredArgsConstructor
public class ChatController {

    private final ChatService chatService;

    // MARK: - Create Chat

    @PostMapping
    public ChatResponse create(
            Authentication auth,
            @RequestBody CreateChatRequest request
    ) {

        return chatService.createChat(
                auth.getName(),
                request
        );
    }

    // MARK: - My Chats

    @GetMapping
    public List<ChatResponse> myChats(
            Authentication auth
    ) {

        return chatService.getMyChats(
                auth.getName()
        );
    }
}