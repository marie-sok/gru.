package gru.app.controller;

import gru.app.dto.SendMessageRequest;
import gru.app.dto.EditMessageRequest;
import gru.app.model.Attachment;
import gru.app.model.Message;
import gru.app.service.MediaStorageService;
import gru.app.service.MessageService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;

@RestController
@RequiredArgsConstructor
public class MessageController {

    private final MessageService messageService;
    private final MediaStorageService mediaStorageService;
    private final SimpMessagingTemplate messagingTemplate;

    @PostMapping("/messages")
    public Message send(
            Authentication authentication,
            @RequestBody SendMessageRequest request
    ) {
        Message message = messageService.send(
                authentication.getName(),
                request
        );
        broadcast(message);
        return message;
    }

    @GetMapping("/chats/{chatId}/messages")
    public List<Message> getMessages(
            Authentication authentication,
            @PathVariable String chatId
    ) {
        return messageService.getMessages(
                authentication.getName(),
                chatId
        );
    }

    @PostMapping("/messages/{messageId}/delivered")
    public Message markDelivered(
            Authentication authentication,
            @PathVariable String messageId
    ) {
        Message message = messageService.markDelivered(
                authentication.getName(),
                messageId
        );
        broadcast(message);
        return message;
    }

    @PostMapping("/messages/{messageId}/read")
    public Message markRead(
            Authentication authentication,
            @PathVariable String messageId
    ) {
        Message message = messageService.markRead(
                authentication.getName(),
                messageId
        );
        broadcast(message);
        return message;
    }

    @PostMapping("/chats/{chatId}/read")
    public List<Message> markChatRead(
            Authentication authentication,
            @PathVariable String chatId
    ) {
        List<Message> messages = messageService.markChatRead(
                authentication.getName(),
                chatId
        );
        messages.forEach(this::broadcast);
        return messages;
    }

    // MARK: - Edit Message

    @PatchMapping("/messages/{messageId}")
    public Message editMessage(
            Authentication authentication,
            @PathVariable String messageId,
            @RequestBody EditMessageRequest request
    ) {
        Message message = messageService.edit(
                authentication.getName(),
                messageId,
                request != null ? request.resolveText() : ""
        );
        broadcast(message);
        return message;
    }

    // MARK: - Media

    @PostMapping(value = "/messages/photo", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public Message sendPhoto(
            Authentication authentication,
            @RequestParam String chatId,
            @RequestParam MultipartFile file,
            @RequestParam(required = false) Double width,
            @RequestParam(required = false) Double height,
            @RequestParam(required = false) String replyToMessageId
    ) {
        return sendMedia(
                authentication,
                chatId,
                file,
                "photo",
                width,
                height,
                null,
                null,
                replyToMessageId
        );
    }

    @PostMapping(value = "/messages/video", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public Message sendVideo(
            Authentication authentication,
            @RequestParam String chatId,
            @RequestParam MultipartFile file,
            @RequestParam(required = false) Double width,
            @RequestParam(required = false) Double height,
            @RequestParam(required = false) Double duration,
            @RequestParam(required = false) String replyToMessageId
    ) {
        return sendMedia(
                authentication,
                chatId,
                file,
                "video",
                width,
                height,
                duration,
                null,
                replyToMessageId
        );
    }

    @PostMapping(value = "/messages/video-note", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public Message sendVideoMessage(
            Authentication authentication,
            @RequestParam String chatId,
            @RequestParam MultipartFile file,
            @RequestParam(required = false) Double width,
            @RequestParam(required = false) Double height,
            @RequestParam(required = false) Double duration,
            @RequestParam(required = false) String replyToMessageId
    ) {
        return sendMedia(
                authentication,
                chatId,
                file,
                "videoNote",
                width,
                height,
                duration,
                null,
                replyToMessageId
        );
    }

    @PostMapping(value = "/messages/document", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public Message sendDocument(
            Authentication authentication,
            @RequestParam String chatId,
            @RequestParam MultipartFile file,
            @RequestParam(required = false) String replyToMessageId
    ) {
        return sendMedia(
                authentication,
                chatId,
                file,
                "document",
                null,
                null,
                null,
                null,
                replyToMessageId
        );
    }

    @PostMapping(value = "/messages/audio", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public Message sendAudio(
            Authentication authentication,
            @RequestParam String chatId,
            @RequestParam MultipartFile file,
            @RequestParam(required = false) Double duration,
            @RequestParam(required = false) String waveform,
            @RequestParam(required = false) String replyToMessageId
    ) {
        return sendMedia(
                authentication,
                chatId,
                file,
                "audio",
                null,
                null,
                duration,
                parseWaveform(waveform),
                replyToMessageId
        );
    }

    // MARK: - Reactions

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
    public Message removeReaction(
            Authentication authentication,
            @PathVariable String messageId
    ) {
        Message message = messageService.removeReaction(
                authentication.getName(),
                messageId
        );
        broadcast(message);
        return message;
    }

    // MARK: - Silent Delete For Everyone

    @DeleteMapping("/messages/{messageId}")
    public Message deleteForEveryone(
            Authentication authentication,
            @PathVariable String messageId
    ) {
        Message tombstone = messageService.deleteForEveryone(
                authentication.getName(),
                messageId
        );
        broadcast(tombstone);
        return tombstone;
    }

    private Message sendMedia(
            Authentication authentication,
            String chatId,
            MultipartFile file,
            String type,
            Double width,
            Double height,
            Double duration,
            List<Double> waveform,
            String replyToMessageId
    ) {
        MediaStorageService.StoredMedia stored = mediaStorageService.save(file);

        Attachment attachment = new Attachment();
        attachment.setType(type);
        attachment.setFileName(stored.originalFileName());
        attachment.setRemoteURL("/media/" + stored.storedName());
        attachment.setWidth(width);
        attachment.setHeight(height);
        attachment.setDuration(duration);
        attachment.setWaveform(waveform);
        attachment.setSize(stored.size());

        Message message = messageService.sendAttachment(
                authentication.getName(),
                chatId,
                attachment,
                replyToMessageId
        );

        broadcast(message);
        return message;
    }

    private List<Double> parseWaveform(String raw) {
        if (raw == null || raw.isBlank()) {
            return Collections.emptyList();
        }

        return Arrays.stream(raw.split(","))
                .map(String::trim)
                .filter(value -> !value.isEmpty())
                .map(value -> {
                    try {
                        return Double.parseDouble(value);
                    } catch (NumberFormatException error) {
                        return 0.05;
                    }
                })
                .limit(64)
                .toList();
    }

    private void broadcast(Message message) {
        if (message == null || message.getChatId() == null || message.getChatId().isBlank()) {
            return;
        }

        messagingTemplate.convertAndSend(
                "/topic/chat/" + message.getChatId(),
                message
        );
    }

    public record ReactionRequest(String reaction) {}
}
