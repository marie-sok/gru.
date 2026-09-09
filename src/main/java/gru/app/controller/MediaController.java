package gru.app.controller;

import gru.app.model.Chat;
import gru.app.model.Message;
import gru.app.repository.ChatRepository;
import gru.app.repository.MessageRepository;
import gru.app.service.MediaStorageService;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequiredArgsConstructor
public class MediaController {

    private final MediaStorageService mediaStorageService;
    private final MessageRepository messageRepository;
    private final ChatRepository chatRepository;

    @GetMapping("/media/{fileName:.+}")
    public ResponseEntity<Resource> media(
            Authentication authentication,
            @PathVariable String fileName
    ) {
        String userId = requireAuthenticatedUser(authentication);
        String remoteURL = "/media/" + fileName;

        Message message = messageRepository.findFirstByAttachmentRemoteURL(remoteURL)
                .orElseThrow(this::notFound);

        if (message.getChatId() == null || message.getChatId().isBlank()) {
            throw notFound();
        }

        Chat chat = chatRepository.findById(message.getChatId())
                .orElseThrow(this::notFound);

        if (chat.getParticipants() == null || !chat.getParticipants().contains(userId)) {
            // Deliberately return 404 rather than 403 so the endpoint does not
            // become an existence oracle for media owned by other chats.
            throw notFound();
        }

        Resource resource = mediaStorageService.load(fileName);
        String contentType = mediaStorageService.contentType(fileName);

        return ResponseEntity.ok()
                .header(HttpHeaders.CACHE_CONTROL, "private, max-age=86400")
                .header("X-Content-Type-Options", "nosniff")
                .contentType(MediaType.parseMediaType(contentType))
                .body(resource);
    }

    private String requireAuthenticatedUser(Authentication authentication) {
        if (authentication == null
                || !authentication.isAuthenticated()
                || authentication.getName() == null
                || authentication.getName().isBlank()) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Unauthorized");
        }
        return authentication.getName();
    }

    private ResponseStatusException notFound() {
        return new ResponseStatusException(HttpStatus.NOT_FOUND, "Media not found");
    }
}
