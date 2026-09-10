package gru.app.controller;

import gru.app.dto.E2EERecoveryBackupRequest;
import gru.app.model.E2EERecoveryBackup;
import gru.app.model.User;
import gru.app.repository.E2EERecoveryBackupRepository;
import gru.app.repository.UserRepository;
import gru.app.security.E2EECryptoVerifier;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.Authentication;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.Base64;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class E2EERecoveryControllerTest {

    private E2EERecoveryBackupRepository backupRepository;
    private UserRepository userRepository;
    private E2EECryptoVerifier cryptoVerifier;
    private E2EERecoveryController controller;

    @BeforeEach
    void setUp() {
        backupRepository = mock(E2EERecoveryBackupRepository.class);
        userRepository = mock(UserRepository.class);
        cryptoVerifier = mock(E2EECryptoVerifier.class);
        controller = new E2EERecoveryController(backupRepository, userRepository, cryptoVerifier);
    }

    @Test
    void storesOnlySignedOpaqueBackupForAuthenticatedOwner() {
        Authentication auth = authenticated("user-a");
        User user = new User();
        user.setId("user-a");
        user.setE2eeSigningPublicKey(Base64.getEncoder().encodeToString(new byte[32]));

        String encrypted = Base64.getEncoder().encodeToString(new byte[96]);
        String signature = Base64.getEncoder().encodeToString(new byte[64]);
        E2EERecoveryBackupRequest request = new E2EERecoveryBackupRequest(
                E2EERecoveryController.RECOVERY_VERSION,
                encrypted,
                signature
        );

        when(userRepository.findById("user-a")).thenReturn(Optional.of(user));
        when(cryptoVerifier.verifyRecoveryBackup(
                user.getE2eeSigningPublicKey(),
                "user-a",
                request.version(),
                encrypted,
                signature
        )).thenReturn(true);
        when(backupRepository.save(any(E2EERecoveryBackup.class))).thenAnswer(invocation -> {
            E2EERecoveryBackup backup = invocation.getArgument(0);
            backup.setUpdatedAt(Instant.parse("2026-09-09T12:00:00Z"));
            return backup;
        });

        var response = controller.put(auth, request);

        assertThat(response.encryptedBundle()).isEqualTo(encrypted);
        assertThat(response.signature()).isEqualTo(signature);
        verify(backupRepository).save(any(E2EERecoveryBackup.class));
    }

    @Test
    void rejectsBackupWithoutValidIdentitySignature() {
        Authentication auth = authenticated("user-a");
        User user = new User();
        user.setId("user-a");
        user.setE2eeSigningPublicKey(Base64.getEncoder().encodeToString(new byte[32]));

        String encrypted = Base64.getEncoder().encodeToString(new byte[96]);
        String signature = Base64.getEncoder().encodeToString(new byte[64]);
        E2EERecoveryBackupRequest request = new E2EERecoveryBackupRequest(
                E2EERecoveryController.RECOVERY_VERSION,
                encrypted,
                signature
        );

        when(userRepository.findById("user-a")).thenReturn(Optional.of(user));
        when(cryptoVerifier.verifyRecoveryBackup(
                user.getE2eeSigningPublicKey(),
                "user-a",
                request.version(),
                encrypted,
                signature
        )).thenReturn(false);

        assertThatThrownBy(() -> controller.put(auth, request))
                .isInstanceOf(ResponseStatusException.class)
                .satisfies(error -> assertThat(((ResponseStatusException) error).getStatusCode().value())
                        .isEqualTo(422));
    }

    @Test
    void returnsOnlyCurrentUsersBackup() {
        Authentication auth = authenticated("user-a");
        E2EERecoveryBackup backup = new E2EERecoveryBackup();
        backup.setUserId("user-a");
        backup.setVersion(E2EERecoveryController.RECOVERY_VERSION);
        backup.setEncryptedBundle(Base64.getEncoder().encodeToString(new byte[96]));
        backup.setSignature(Base64.getEncoder().encodeToString(new byte[64]));
        backup.setUpdatedAt(Instant.now());
        when(backupRepository.findById("user-a")).thenReturn(Optional.of(backup));

        var response = controller.get(auth);

        assertThat(response.version()).isEqualTo(E2EERecoveryController.RECOVERY_VERSION);
        verify(backupRepository).findById("user-a");
    }

    private Authentication authenticated(String userId) {
        Authentication auth = mock(Authentication.class);
        when(auth.isAuthenticated()).thenReturn(true);
        when(auth.getName()).thenReturn(userId);
        return auth;
    }
}
