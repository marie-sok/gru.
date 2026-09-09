package gru.app.dto;

import lombok.Data;

@Data
public class E2EEMessageRequest {
    private String chatId;
    private String clientMessageId;
    private String encryptedPayload;
    private String encryptionVersion;
    private String senderEphemeralPublicKey;

    /**
     * E2EE v2 only: a second ciphertext encrypted to the sender's own
     * long-lived X25519 identity. It lets a restored/replacement device read
     * historical outgoing messages without server plaintext.
     */
    private String senderRecoveryEncryptedPayload;
    private String senderRecoveryEphemeralPublicKey;

    private String signature;
    private String senderKeyFingerprint;
    private String replyToMessageId;
}
