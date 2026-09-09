package gru.app.controller;

import gru.app.dto.EditMessageRequest;
import gru.app.dto.SendMessageRequest;
import gru.app.model.Message;
import gru.app.service.MessageService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@RestController
@RequiredArgsConstructor
public class MessageController {

    private final MessageService messageService;
    private final SimpMessagingTemplate messagingTemplate;

    /**
     * Historical plaintext JSON send route. It remains mapped only so stale
     * clients receive an explicit upgrade signal instead of silently writing
     * plaintext into the message collection.
     */
    @PostMapping("/messages")
    public Message send(Authentication authentication, @RequestBody SendMessageRequest request) {
        throw legacyPlaintextTransportDisabled();
    }

    @GetMapping("/chats/{chatId}/messages")
    public List<Message> getMessages(Authentication authentication, @PathVariable String chatId) {
        return messageService.getMessages(authentication.getName(), chatId);
    }

    @PostMapping("/messages/{messageId}/delivered")
    public Message markDelivered(Authentication authentication, @PathVariable String messageId) {
        Message message = messageService.markDelivered(authentication.getName(), messageId);
        broadcast(message);
        return message;
    }

    @PostMapping("/messages/{messageId}/read")
    public Message markRead(Authentication authentication, @PathVariable String messageId) {
        Message message = messageService.markRead(authentication.getName(), messageId);
        broadcast(message);
        return message;
    }

    @PostMapping("/chats/{chatId}/read")
    public List<Message> markChatRead(Authentication authentication, @PathVariable String chatId) {
        List<Message> messages = messageService.markChatRead(authentication.getName(), chatId);
        messages.forEach(this::broadcast);
        return messages;
    }

    /**
     * Plaintext edits would overwrite the encrypted-message contract. New
     * clients must use PATCH /messages/{id}/e2ee.
     */
    @PatchMapping("/messages/{messageId}")
    public Message editMessage(
            Authentication authentication,
            @PathVariable String messageId,
            @RequestBody EditMessageRequest request
    ) {
        throw legacyPlaintextTransportDisabled();
    }

    /*
     * Legacy plaintext multipart upload routes were intentionally removed:
     *   /messages/photo
     *   /messages/video
     *   /messages/video-note
     *   /messages/document
     *   /messages/audio
     *
     * E2EE media uses /messages/media-e2ee. Removing the old mappings avoids
     * both a downgrade path and unnecessary multipart parsing of rejected
     * plaintext uploads.
     */

    @PostMapping("/messages/{messageId}/reaction")
    public Message setReaction(
            Authentication authentication,
            @PathVariable String messageId,
            @RequestBody ReactionRequest request
    ) {
        Message message = messageService.setReaction(
                authentication.getName(),
                messageId,
                request.reaction()
        );
        broadcast(message);
        return message;
    }

    @DeleteMapping("/messages/{messageId}/reaction")
    public Message removeReaction(Authentication authentication, @PathVariable String messageId) {
        Message message = messageService.removeReaction(authentication.getName(), messageId);
        broadcast(message);
        return message;
    }

    @DeleteMapping("/messages/{messageId}/me")
    public Message deleteForMe(Authentication authentication, @PathVariable String messageId) {
        return messageService.deleteForMe(authentication.getName(), messageId);
    }

    @DeleteMapping("/messages/{messageId}")
    public Message deleteForEveryone(Authentication authentication, @PathVariable String messageId) {
        Message tombstone = messageService.deleteForEveryone(authentication.getName(), messageId);
        broadcast(tombstone);
        return tombstone;
    }

    private ResponseStatusException legacyPlaintextTransportDisabled() {
        return new ResponseStatusException(
                HttpStatus.UPGRADE_REQUIRED,
                "Plaintext message writes are disabled; update to the E2EE client"
        );
    }

    private void broadcast(Message message) {
        if (message == null || message.getChatId() == null || message.getChatId().isBlank()) {
            return;
        }
        messagingTemplate.convertAndSend("/topic/chat/" + message.getChatId(), message);
    }

    public record ReactionRequest(String reaction) {}
}
