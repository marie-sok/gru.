package gru.app.controller;

import gru.app.model.Chat;
import gru.app.service.ChatCacheService;
import gru.app.service.ChatService;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import lombok.Setter;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Getter
@Setter
@RestController
@RequestMapping("/chat")
@RequiredArgsConstructor
public class ChatController {

    private ChatService chatService;

    @PostMapping("/private")
    public Chat createPrivate(
            @RequestParam String user1,
            @RequestParam String user2
    ) {
        return chatService.createPrivateChat(user1, user2);
    }

    @PostMapping("/group")
    public Chat createGroup(
            @RequestParam String creator,
            @RequestParam String title,
            @RequestBody List<String> users
    ) {
        return chatService.createGroup(creator, title, users);
    }

}