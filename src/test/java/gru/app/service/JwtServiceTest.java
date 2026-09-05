package gru.app.service;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class JwtServiceTest {

    private static final String SECRET =
            "gru-beta-tests-use-a-secret-longer-than-thirty-two-bytes";

    @Test
    void generatedTokenRoundTripsUserId() {
        JwtService service = new JwtService(SECRET);

        String token = service.generateToken("user-42");

        assertTrue(service.isValid(token));
        assertEquals("user-42", service.extractUserId(token));
    }

    @Test
    void tokenSignedWithAnotherSecretIsRejected() {
        JwtService issuer = new JwtService(SECRET);
        JwtService verifier = new JwtService(
                "another-gru-beta-secret-longer-than-thirty-two-bytes"
        );

        assertFalse(verifier.isValid(issuer.generateToken("user-42")));
    }

    @Test
    void shortConfiguredSecretIsRejectedAtStartup() {
        assertThrows(IllegalStateException.class, () -> new JwtService("too-short"));
    }
}
