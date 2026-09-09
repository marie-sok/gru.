package gru.app.controller;

import gru.app.dto.E2EEMessageRequest;
import gru.app.model.Attachment;
import gru.app.model.Message;
import gru.app.service.E2EEMessageService;
import gru.app.service.MediaStorageService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.HttpStatus;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Set;

@RestController
@RequiredArgsConstructor
public class E2EEMessageController {

    private static final Set<String> ALLOWED_MEDIA_TYPES = Set.of(
            "photo", "video", "videoNote", "document", "audio"
    );

    private final E2EEMessageService e2eeMessageService;
    private final MediaStorageService mediaStorageService;
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

    @PostMapping(value = "/messages/media-e2ee", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public Message sendEncryptedMedia(
            Authentication authentication,
            @RequestParam String chatId,
            @RequestParam MultipartFile file,
            @RequestParam String type,
            @RequestParam String fileName,
            @RequestParam(required = false) String mimeType,
            @RequestParam String clientMessageId,
            @RequestParam String encryptedPayload,
            @RequestParam String encryptionVersion,
            @RequestParam String senderEphemeralPublicKey,
            @RequestParam String signature,
            @RequestParam String senderKeyFingerprint,
            @RequestParam(required = false) Double width,
            @RequestParam(required = false) Double height,
            @RequestParam(required = false) Double duration,
            @RequestParam(required = false) String waveform,
            @RequestParam(required = false) String replyToMessageId
    ) {
        if (!ALLOWED_MEDIA_TYPES.contains(type)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unsupported encrypted media type");
        }
        if (fileName == null || fileName.isBlank() || fileName.length() > 255) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid media file name");
        }

        MediaStorageService.StoredMedia stored = mediaStorageService.save(file);
        String remoteURL = "/media/" + stored.storedName();

        try {
            Attachment attachment = new Attachment();
            attachment.setType(type);
            attachment.setFileName(fileName.trim());
            attachment.setRemoteURL(remoteURL);
            attachment.setWidth(width);
            attachment.setHeight(height);
            attachment.setDuration(duration);
            attachment.setWaveform(parseWaveform(waveform));
            attachment.setSize(stored.size());

            E2EEMessageRequest request = new E2EEMessageRequest();
            request.setChatId(chatId);
            request.setClientMessageId(clientMessageId);
            request.setEncryptedPayload(encryptedPayload);
            request.setEncryptionVersion(encryptionVersion);
            request.setSenderEphemeralPublicKey(senderEphemeralPublicKey);
            request.setSignature(signature);
            request.setSenderKeyFingerprint(senderKeyFingerprint);
            request.setReplyToMessageId(replyToMessageId);

            Message message = e2eeMessageService.sendMedia(
                    authentication.getName(),
                    request,
                    attachment
            );
            broadcast(message);
            return message;
        } catch (RuntimeException error) {
            mediaStorageService.deleteByRemoteURL(remoteURL);
            throw error;
        }
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
                .map(value -> Math.max(0.04, Math.min(1.0, value)))
                .limit(64)
                .toList();
    }

    private void broadcast(Message message) {
        messagingTemplate.convertAndSend("/topic/chat/" + message.getChatId(), message);
    }
}
