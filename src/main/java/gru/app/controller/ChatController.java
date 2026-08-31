package gru.app.controller;

import gru.app.dto.ChatResponse;
import gru.app.dto.CreateChatRequest;
import gru.app.model.Message;
import gru.app.service.ChatService;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;

@RestController
@RequestMapping("/chats")
@RequiredArgsConstructor
public class ChatController {

    private final ChatService chatService;
    private final SimpMessagingTemplate messagingTemplate;

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

    // MARK: - Delete Chat For Everyone

    @DeleteMapping("/{chatId}")
    public void delete(
            Authentication auth,
            @PathVariable String chatId
    ) {
        List<String> participants = chatService.deleteChatForEveryone(auth.getName(), chatId);

        Message event = new Message();
        event.setId("chat-deleted-" + chatId);
        event.setChatId(chatId);
        event.setSenderId(auth.getName());
        event.setText("__GRU_CHAT_DELETED__");
        event.setCreatedAt(Instant.now());
        event.setDeletedAt(Instant.now());

        messagingTemplate.convertAndSend(
                "/topic/chat/" + chatId,
                event
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