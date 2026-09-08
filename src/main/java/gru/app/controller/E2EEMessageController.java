package gru.app.controller;

import gru.app.dto.E2EEMessageRequest;
import gru.app.model.Message;
import gru.app.service.E2EEMessageService;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
public class E2EEMessageController {

    private final E2EEMessageService e2eeMessageService;
    private final SimpMessagingTemplate messagingTemplate;

    @PostMapping("/messages/e2ee")
    public Message send(
            Authentication authentication,
            @RequestBody E2EEMessageRequest request
    ) {
        Message message = e2eeMessageService.send(authentication.getName(), request);
        broadcast(message);
        return message;
    }

    @PatchMapping("/messages/{messageId}/e2ee")
    public Message edit(
            Authentication authentication,
            @PathVariable String messageId,
            @RequestBody E2EEMessageRequest request
    ) {
        Message message = e2eeMessageService.edit(authentication.getName(), messageId, request);
        broadcast(message);
        return message;
    }

    private void broadcast(Message message) {
        messagingTemplate.convertAndSend("/topic/chat/" + message.getChatId(), message);
    }
}
