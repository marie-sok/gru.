package gru.app.controller;

import gru.app.model.Chat;
import gru.app.model.Message;
import gru.app.repository.ChatRepository;
import gru.app.repository.MessageRepository;
import gru.app.service.MediaStorageService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.security.core.Authentication;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class MediaControllerTest {

    private MediaStorageService mediaStorageService;
    private MessageRepository messageRepository;
    private ChatRepository chatRepository;
    private MediaController controller;

    @BeforeEach
    void setUp() {
        mediaStorageService = mock(MediaStorageService.class);
        messageRepository = mock(MessageRepository.class);
        chatRepository = mock(ChatRepository.class);
        controller = new MediaController(mediaStorageService, messageRepository, chatRepository);
    }

    @Test
    void participantCanReadMedia() {
        Authentication auth = authenticated("user-a");
        Message message = message("chat-1");
        Chat chat = chat("chat-1", List.of("user-a", "user-b"));

        when(messageRepository.findFirstByAttachmentRemoteURL("/media/cipher.bin"))
                .thenReturn(Optional.of(message));
        when(chatRepository.findById("chat-1")).thenReturn(Optional.of(chat));
        when(mediaStorageService.load("cipher.bin"))
                .thenReturn(new ByteArrayResource(new byte[]{1, 2, 3}));
        when(mediaStorageService.contentType("cipher.bin"))
                .thenReturn("application/octet-stream");

        var response = controller.media(auth, "cipher.bin");

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getHeaders().getFirst("X-Content-Type-Options")).isEqualTo("nosniff");
    }

    @Test
    void nonParticipantGetsNotFoundWithoutBlobRead() {
        Authentication auth = authenticated("user-x");
        Message message = message("chat-1");
        Chat chat = chat("chat-1", List.of("user-a", "user-b"));

        when(messageRepository.findFirstByAttachmentRemoteURL("/media/cipher.bin"))
                .thenReturn(Optional.of(message));
        when(chatRepository.findById("chat-1")).thenReturn(Optional.of(chat));

        assertThatThrownBy(() -> controller.media(auth, "cipher.bin"))
                .isInstanceOf(ResponseStatusException.class)
                .satisfies(error -> assertThat(((ResponseStatusException) error).getStatusCode().value())
                        .isEqualTo(404));

        verify(mediaStorageService, never()).load("cipher.bin");
    }

    @Test
    void unknownMediaDoesNotRevealAnything() {
        Authentication auth = authenticated("user-a");
        when(messageRepository.findFirstByAttachmentRemoteURL("/media/missing.bin"))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> controller.media(auth, "missing.bin"))
                .isInstanceOf(ResponseStatusException.class)
                .satisfies(error -> assertThat(((ResponseStatusException) error).getStatusCode().value())
                        .isEqualTo(404));
    }

    private Authentication authenticated(String userId) {
        Authentication auth = mock(Authentication.class);
        when(auth.isAuthenticated()).thenReturn(true);
        when(auth.getName()).thenReturn(userId);
        return auth;
    }

    private Message message(String chatId) {
        Message message = new Message();
        message.setChatId(chatId);
        return message;
    }

    private Chat chat(String id, List<String> participants) {
        Chat chat = new Chat();
        chat.setId(id);
        chat.setParticipants(participants);
        return chat;
    }
}
