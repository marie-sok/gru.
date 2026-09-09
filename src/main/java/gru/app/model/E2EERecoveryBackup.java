package gru.app.model;

import lombok.Data;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

@Document(collection = "e2ee_recovery_backups")
@Data
public class E2EERecoveryBackup {

    @Id
    private String userId;

    private String version;

    /**
     * Client-side encrypted recovery bundle. The recovery key never reaches
     * the GRU backend; the server stores opaque ciphertext only.
     */
    private String encryptedBundle;

    /** Ed25519 signature made by the currently registered E2EE identity. */
    private String signature;

    private Instant updatedAt;
}
