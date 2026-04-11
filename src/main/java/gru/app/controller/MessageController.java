package gru.app.controller;

import gru.app.dto.MessageRequest;
import gru.app.dto.MessageResponse;
import gru.app.model.Message;
import gru.app.service.MessageService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/messages")
@RequiredArgsConstructor
public class MessageController {

    private final MessageService messageService;

    @PostMapping("/send")
    public MessageResponse sendMessage(@RequestParam String senderId,
                                       @RequestBody MessageRequest request) {
        return messageService.sendMessage(senderId, request);
    }

    @PutMapping("/edit/{id}")
    public MessageResponse editMessage(@PathVariable String id,
                                       @RequestBody String newContent) {
        return messageService.editMessage(id, newContent);
    }

    @DeleteMapping("/delete/{id}")
    public void deleteMessage(@PathVariable String id) {
        messageService.deleteMessage(id);
    }

    @GetMapping("/chat/{chatId}")
    public List<Message<?>> getChatMessages(@PathVariable String chatId) {
        return messageService.getChatMessages(chatId);
    }
}