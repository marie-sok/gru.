package gru.app.dto;

import java.time.Instant;

public record E2EERecoveryBackupResponse(
        String version,
        String encryptedBundle,
        String signature,
        Instant updatedAt
) {
}
