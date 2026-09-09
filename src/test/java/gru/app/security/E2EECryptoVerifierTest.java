package gru.app.security;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.MessageDigest;
import java.security.Signature;
import java.util.Base64;
import java.util.HexFormat;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class E2EECryptoVerifierTest {

    private final E2EECryptoVerifier verifier = new E2EECryptoVerifier();

    @Test
    void verifiesSignedEnvelopeAndRejectsTampering() throws Exception {
        KeyPair pair = KeyPairGenerator.getInstance("Ed25519").generateKeyPair();
        String publicKey = rawPublicKeyBase64(pair);
        String fingerprint = HexFormat.of().formatHex(
                MessageDigest.getInstance("SHA-256").digest(Base64.getDecoder().decode(publicKey))
        );

        String version = "gru-e2ee-v1";
        String chatId = "chat-1";
        String senderId = "alice";
        String receiverId = "bob";
        String clientMessageId = UUID.randomUUID().toString();
        String ephemeral = Base64.getEncoder().encodeToString(new byte[32]);
        String ciphertext = Base64.getEncoder().encodeToString("ciphertext".getBytes(StandardCharsets.UTF_8));

        String canonical = String.join("|",
                version,
                chatId,
                senderId,
                receiverId,
                clientMessageId,
                ephemeral,
                ciphertext,
                fingerprint
        );
        String signature = sign(pair, canonical);

        assertTrue(verifier.fingerprintMatches(publicKey, fingerprint));
        assertTrue(verifier.verifyMessageSignature(
                publicKey,
                version,
                chatId,
                senderId,
                receiverId,
                clientMessageId,
                ephemeral,
                ciphertext,
                fingerprint,
                signature
        ));
        assertFalse(verifier.verifyMessageSignature(
                publicKey,
                version,
                chatId,
                senderId,
                receiverId,
                clientMessageId,
                ephemeral,
                ciphertext + "tampered",
                fingerprint,
                signature
        ));
    }

    @Test
    void verifiesSignedKeyRotation() throws Exception {
        KeyPair pair = KeyPairGenerator.getInstance("Ed25519").generateKeyPair();
        String publicKey = rawPublicKeyBase64(pair);
        String userId = "alice";
        String newAgreement = Base64.getEncoder().encodeToString(new byte[32]);
        String newSigning = Base64.getEncoder().encodeToString(new byte[32]);
        String canonical = String.join("|",
                "gru-e2ee-key-rotation-v1",
                userId,
                newAgreement,
                newSigning
        );
        String signature = sign(pair, canonical);

        assertTrue(verifier.verifyKeyRotation(
                publicKey,
                userId,
                newAgreement,
                newSigning,
                signature
        ));
        assertFalse(verifier.verifyKeyRotation(
                publicKey,
                userId,
                newAgreement,
                newSigning + "x",
                signature
        ));
    }

    private String sign(KeyPair pair, String payload) throws Exception {
        Signature signer = Signature.getInstance("Ed25519");
        signer.initSign(pair.getPrivate());
        signer.update(payload.getBytes(StandardCharsets.UTF_8));
        return Base64.getEncoder().encodeToString(signer.sign());
    }

    private String rawPublicKeyBase64(KeyPair pair) {
        byte[] encoded = pair.getPublic().getEncoded();
        byte[] raw = new byte[32];
        System.arraycopy(encoded, encoded.length - raw.length, raw, 0, raw.length);
        return Base64.getEncoder().encodeToString(raw);
    }
}
