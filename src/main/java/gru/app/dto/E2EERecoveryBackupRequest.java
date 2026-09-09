package gru.app.dto;

public record E2EERecoveryBackupRequest(
        String version,
        String encryptedBundle,
        String signature
) {
}
