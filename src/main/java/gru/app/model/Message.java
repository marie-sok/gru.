package gru.app.model;

import lombok.Data;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;
import java.util.HashSet;
import java.util.Set;

@Document(collection = "messages")
@Data
public class Message {

    @Id
    private String id;

    private String chatId;

    private String senderId;

    private String receiverId;

    /** Plaintext for legacy/non-E2EE messages only. */
    private String text;

    /** Opaque base64 ciphertext produced on the sender device. */
    private String encryptedPayload;

    /** Protocol version, e.g. "gru-e2ee-v1". */
    private String encryptionVersion;

    /** Sender ephemeral X25519 public key, base64 encoded. */
    private String senderEphemeralPublicKey;

    /** Signature over the canonical encrypted envelope, base64 encoded. */
    private String e2eeSignature;

    /** SHA-256 fingerprint of the sender signing identity key. */
    private String senderKeyFingerprint;

    private Instant createdAt;

    private Instant deliveredAt;

    private Instant readAt;

    private Instant deletedAt;

    private String reaction;

    private Attachment attachment;

    private Boolean isEdited;

    private Instant editedAt;

    private ReplyReference replyTo;

    /**
     * Per-account soft-hide state for "delete for me".
     * Kept on the message so history filtering survives app restarts and reloads.
     */
    private Set<String> hiddenForUserIds = new HashSet<>();
}
