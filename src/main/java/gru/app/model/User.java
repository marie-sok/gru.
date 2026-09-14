package gru.app.model;

import lombok.Data;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;
import org.springframework.data.mongodb.core.mapping.Field;

import java.time.Instant;
import java.util.HashSet;
import java.util.Set;

@Document(collection = "users")
@Data
public class User {

    @Id
    private String id;

    private String phone;

    /** Current bcrypt credential field used by new GRU accounts. */
    private String password;

    /**
     * Compatibility with accounts created by the original backend, which stored
     * the bcrypt credential under Mongo field "passwordHash". Keep this mapped
     * until every active legacy account has been migrated on successful login.
     */
    @Field("passwordHash")
    private String legacyPasswordHash;

    private String nickname;

    private Set<String> blockedUserIds = new HashSet<>();

    /** Public X25519 identity key. Private material must never reach the server. */
    private String e2eeKeyAgreementPublicKey;

    /** Public Ed25519 signing key used to authenticate encrypted envelopes. */
    private String e2eeSigningPublicKey;

    private Instant e2eeKeyUpdatedAt;
}
