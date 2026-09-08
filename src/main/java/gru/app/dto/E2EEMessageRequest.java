package gru.app.dto;

import lombok.Data;

@Data
public class E2EEMessageRequest {
    private String chatId;
    private String clientMessageId;
    private String encryptedPayload;
    private String encryptionVersion;
    private String senderEphemeralPublicKey;
    private String signature;
    private String senderKeyFingerprint;
    private String replyToMessageId;
}
