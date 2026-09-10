package gru.app.controller;

import gru.app.model.Chat;
import gru.app.model.User;
import gru.app.repository.ChatRepository;
import gru.app.repository.UserRepository;
import gru.app.security.E2EECryptoVerifier;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.Authentication;
import org.springframework.web.server.ResponseStatusException;

import java.util.Base64;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class E2EEKeyControllerTest {

    private UserRepository userRepository;
    private ChatRepository chatRepository;
    private E2EEKeyController controller;

    @BeforeEach
    void setUp() {
        userRepository = mock(UserRepository.class);
        chatRepository = mock(ChatRepository.class);
        controller = new E2EEKeyController(
                userRepository,
                chatRepository,
                mock(E2EECryptoVerifier.class)
        );
    }

    @Test
    void ownerCanReadOwnIdentity() {
        User alice = user("alice");
        when(userRepository.findById("alice")).thenReturn(Optional.of(alice));

        var response = controller.get(authenticated("alice"), "alice");

        assertThat(response.userId()).isEqualTo("alice");
    }

    @Test
    void chatParticipantCanReadPeerIdentity() {
        User alice = user("alice");
        User bob = user("bob");
        Chat chat = new Chat();
        chat.setId("chat-1");
        chat.setParticipants(List.of("alice", "bob"));

        when(userRepository.findById("alice")).thenReturn(Optional.of(alice));
        when(userRepository.findById("bob")).thenReturn(Optional.of(bob));
        when(chatRepository.findByParticipantsContains("alice")).thenReturn(List.of(chat));

        var response = controller.get(authenticated("alice"), "bob");

        assertThat(response.userId()).isEqualTo("bob");
    }

    @Test
    void authenticatedOutsiderGetsNonEnumeratingNotFound() {
        User alice = user("alice");
        when(userRepository.findById("alice")).thenReturn(Optional.of(alice));
        when(chatRepository.findByParticipantsContains("alice")).thenReturn(List.of());

        assertThatThrownBy(() -> controller.get(authenticated("alice"), "charlie"))
                .isInstanceOf(ResponseStatusException.class)
                .satisfies(error -> assertThat(((ResponseStatusException) error).getStatusCode().value())
                        .isEqualTo(404));
    }

    private User user(String id) {
        User user = new User();
        user.setId(id);
        user.setE2eeKeyAgreementPublicKey(Base64.getEncoder().encodeToString(new byte[32]));
        user.setE2eeSigningPublicKey(Base64.getEncoder().encodeToString(new byte[32]));
        return user;
    }

    private Authentication authenticated(String userId) {
        Authentication auth = mock(Authentication.class);
        when(auth.getName()).thenReturn(userId);
        when(auth.isAuthenticated()).thenReturn(true);
        return auth;
    }
}
