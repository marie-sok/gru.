package gru.app.controller;

import gru.app.dto.SendMessageRequest;
import gru.app.model.Message;
import gru.app.service.MessageService;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequiredArgsConstructor
public class MessageController {

    private final MessageService messageService;

    private final SimpMessagingTemplate messagingTemplate;

    // MARK: ========================================
    // MARK: SEND
    // MARK: ========================================

    @PostMapping("/messages")
    public Message send(
            Authentication authentication,
            @RequestBody SendMessageRequest request
    ) {

        Message message =
                messageService.send(
                        authentication.getName(),
                        request
                );

        broadcast(
                message
        );

        return message;
    }

    // MARK: ========================================
    // MARK: HISTORY
    // MARK: ========================================

    @GetMapping(
            "/chats/{chatId}/messages"
    )
    public List<Message> getMessages(
            Authentication authentication,
            @PathVariable String chatId
    ) {

        return messageService
                .getMessages(
                        authentication.getName(),
                        chatId
                );
    }

    // MARK: ========================================
    // MARK: DELIVERED
    // MARK: ========================================

    @PostMapping(
            "/messages/{messageId}/delivered"
    )
    public Message markDelivered(
            Authentication authentication,
            @PathVariable String messageId
    ) {

        Message message =
                messageService.markDelivered(
                        authentication.getName(),
                        messageId
                );

        broadcast(
                message
        );

        return message;
    }

    // MARK: ========================================
    // MARK: READ SINGLE
    // MARK: ========================================

    @PostMapping(
            "/messages/{messageId}/read"
    )
    public Message markRead(
            Authentication authentication,
            @PathVariable String messageId
    ) {

        Message message =
                messageService.markRead(
                        authentication.getName(),
                        messageId
                );

        broadcast(
                message
        );

        return message;
    }

    // MARK: ========================================
    // MARK: READ CHAT
    // MARK: ========================================

    @PostMapping(
            "/chats/{chatId}/read"
    )
    public List<Message> markChatRead(
            Authentication authentication,
            @PathVariable String chatId
    ) {

        List<Message> messages =
                messageService.markChatRead(
                        authentication.getName(),
                        chatId
                );

        for (
                Message message :
                messages
        ) {

            broadcast(
                    message
            );
        }

        return messages;
    }

    // MARK: ========================================
    // MARK: BROADCAST
    // MARK: ========================================

    private void broadcast(
            Message message
    ) {

        if (
                message == null ||
                        message.getChatId() == null ||
                        message.getChatId().isBlank()
        ) {

            return;
        }

        messagingTemplate.convertAndSend(
                "/topic/chat/" +
                        message.getChatId(),
                message
        );
    }
}