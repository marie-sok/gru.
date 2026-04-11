package gru.app.controller;

import gru.app.dto.AuthResponse;
import gru.app.dto.LoginRequest;
import gru.app.dto.MessageRequest;
import gru.app.dto.RegisterRequest;
import gru.app.model.User;
import gru.app.service.AuthService;
import gru.app.service.ChatService;
import gru.app.service.UserService;
import functional.unique.creator.kerry.dto.*;

import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class ChatController{

    private final AuthService authService;
    private final UserService userService;
    private final ChatService chatService;


    @PostMapping("/auth/register")
    public AuthResponse register(@RequestBody RegisterRequest req) {
        return authService.register(req);
    }

    @PostMapping("/auth/login")
    public AuthResponse login(@RequestBody LoginRequest req) {
        return authService.login(req);
    }


    @GetMapping("/users/me")
    public User me(@RequestHeader("Authorization") String token) {
        return userService.UserService(token);
    }

    @GetMapping("/users/search")
    public List<User> search(@RequestParam String query) {
        return userService.search(query);
    }

    @PostMapping("/users/block/{id}")
    public void block(@RequestHeader("Authorization") String token,
                      @PathVariable String id) {
        userService.block(token, id);
    }

    @PostMapping("/users/unblock/{id}")
    public void unblock(@RequestHeader("Authorization") String token,
                        @PathVariable String id) {
        userService.unblock(token, id);
    }


    @PostMapping("/chats")
    public String createChat(@RequestHeader("Authorization") String token,
                             @RequestBody List<String> userIds) {
        return chatService.createChat(token, userIds);
    }

    @GetMapping("/chats")
    public List<?> getChats(@RequestHeader("Authorization") String token) {
        return chatService.getUserChats(token);
    }


    @PostMapping("/messages")
    public void send(@RequestHeader("Authorization") String token,
                     @RequestBody MessageRequest req) {
        chatService.sendMessage(token, req);
    }

    @PutMapping("/messages/{id}")
    public void edit(@RequestHeader("Authorization") String token,
                     @PathVariable String id,
                     @RequestBody MessageRequest req) {
        chatService.editMessage(token, id, req);
    }

    @DeleteMapping("/messages/{id}")
    public void delete(@RequestHeader("Authorization") String token,
                       @PathVariable String id) {
        chatService.deleteMessage(token, id);
    }

    @PostMapping("/messages/read/{chatId}")
    public void read(@RequestHeader("Authorization") String token,
                     @PathVariable String chatId) {
        chatService.markAsRead(token, chatId);
    }


    @PostMapping("/typing/{chatId}")
    public void typing(@RequestHeader("Authorization") String token,
                       @PathVariable String chatId) {
        chatService.typing(token, chatId);
    }

    @PostMapping("/status/online")
    public void online(@RequestHeader("Authorization") String token) {
        userService.setOnline(token);
    }

    @PostMapping("/status/offline")
    public void offline(@RequestHeader("Authorization") String token) {
        userService.setOffline(token);
    }


    @PutMapping("/settings/visibility")
    public void visibility(@RequestHeader("Authorization") String token,
                           @RequestParam boolean visible) {
        userService.setVisibility(token, visible);
    }
}