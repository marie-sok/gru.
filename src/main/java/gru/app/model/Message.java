package gru.app.model;

import lombok.Data;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.CompoundIndex;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;
import java.util.HashSet;
import java.util.Set;

@Document(collection = "messages")
@CompoundIndex(
        name = "uniq_e2ee_sender_client_message",
        def = "{'senderId': 1, 'e2eeClientMessageId': 1}",
        unique = true,
        partialFilter = "{'e2eeClientMessageId': {'$type': 'string'}}"
)
@Data
public class Message {

    @Id
    private String id;

    private String chatId;
    private String senderId;
    private String receiverId;

    /** Plaintext for legacy/non-E2EE messages only. */
    private String text;

    /** Client-generated UUID, signed into the E2EE envelope for replay/idempotency protection. */
    private String e2eeClientMessageId;

    /** Recipient ciphertext produced on the sender device. */
    private String encryptedPayload;

    /** Protocol version, e.g. "gru-e2ee-v1" / "gru-e2ee-v2". */
    private String encryptionVersion;

    /** Recipient-envelope ephemeral X25519 public key, base64 encoded. */
    private String senderEphemeralPublicKey;

    /**
     * v2 sender-only recovery ciphertext. It contains the same plaintext
     * payload encrypted to the sender's own long-lived X25519 identity so a
     * restored device can read outgoing history. The server cannot decrypt it.
     */
    private String senderRecoveryEncryptedPayload;

    /** Ephemeral X25519 public key for senderRecoveryEncryptedPayload. */
    private String senderRecoveryEphemeralPublicKey;

    /** Signature over the complete canonical encrypted envelope, base64 encoded. */
    private String e2eeSignature;

    /** SHA-256 fingerprint of the sender signing identity key. */
    private String senderKeyFingerprint;

    /** Public Ed25519 identity key used by clients to verify this envelope offline. */
    private String senderSigningPublicKey;

    /** Public X25519 identity key, pinned together with the signing key as one peer identity. */
    private String senderKeyAgreementPublicKey;

    private Instant createdAt;
    private Instant deliveredAt;
    private Instant readAt;
    private Instant deletedAt;
    private String reaction;
    private Attachment attachment;
    private Boolean isEdited;
    private Instant editedAt;
    private ReplyReference replyTo;
    private Set<String> hiddenForUserIds = new HashSet<>();
}
