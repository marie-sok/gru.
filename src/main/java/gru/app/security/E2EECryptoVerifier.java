package gru.app.security;

import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.MessageDigest;
import java.security.PublicKey;
import java.security.Signature;
import java.security.spec.X509EncodedKeySpec;
import java.util.Base64;
import java.util.HexFormat;

@Component
public class E2EECryptoVerifier {

    private static final byte[] ED25519_X509_PREFIX = HexFormat.of().parseHex(
            "302a300506032b6570032100"
    );

    public boolean fingerprintMatches(String rawSigningPublicKeyBase64, String claimedFingerprint) {
        try {
            byte[] raw = Base64.getDecoder().decode(rawSigningPublicKeyBase64);
            if (raw.length != 32 || claimedFingerprint == null) return false;

            String actual = HexFormat.of().formatHex(
                    MessageDigest.getInstance("SHA-256").digest(raw)
            );

            return MessageDigest.isEqual(
                    actual.getBytes(StandardCharsets.US_ASCII),
                    claimedFingerprint.toLowerCase().getBytes(StandardCharsets.US_ASCII)
            );
        } catch (Exception error) {
            return false;
        }
    }

    public boolean verifyMessageSignature(
            String signingPublicKeyBase64,
            String version,
            String chatId,
            String senderId,
            String receiverId,
            String clientMessageId,
            String ephemeralPublicKey,
            String encryptedPayload,
            String senderKeyFingerprint,
            String signatureBase64
    ) {
        String canonical = String.join("|",
                version,
                chatId,
                senderId,
                receiverId,
                clientMessageId,
                ephemeralPublicKey,
                encryptedPayload,
                senderKeyFingerprint
        );
        return verify(
                signingPublicKeyBase64,
                canonical.getBytes(StandardCharsets.UTF_8),
                signatureBase64
        );
    }

    public boolean verifyKeyRotation(
            String oldSigningPublicKeyBase64,
            String userId,
            String newAgreementPublicKey,
            String newSigningPublicKey,
            String signatureBase64
    ) {
        String canonical = String.join("|",
                "gru-e2ee-key-rotation-v1",
                userId,
                newAgreementPublicKey,
                newSigningPublicKey
        );
        return verify(
                oldSigningPublicKeyBase64,
                canonical.getBytes(StandardCharsets.UTF_8),
                signatureBase64
        );
    }


    public boolean verifyRecoveryBackup(
            String signingPublicKeyBase64,
            String userId,
            String version,
            String encryptedBundle,
            String signatureBase64
    ) {
        String canonical = String.join("|",
                "gru-e2ee-recovery-backup-v1",
                userId,
                version,
                encryptedBundle
        );
        return verify(
                signingPublicKeyBase64,
                canonical.getBytes(StandardCharsets.UTF_8),
                signatureBase64
        );
    }

    private boolean verify(
            String rawSigningPublicKeyBase64,
            byte[] payload,
            String signatureBase64
    ) {
        try {
            byte[] raw = Base64.getDecoder().decode(rawSigningPublicKeyBase64);
            byte[] signatureBytes = Base64.getDecoder().decode(signatureBase64);
            if (raw.length != 32 || signatureBytes.length != 64) return false;

            byte[] x509 = new byte[ED25519_X509_PREFIX.length + raw.length];
            System.arraycopy(ED25519_X509_PREFIX, 0, x509, 0, ED25519_X509_PREFIX.length);
            System.arraycopy(raw, 0, x509, ED25519_X509_PREFIX.length, raw.length);

            PublicKey publicKey = KeyFactory.getInstance("Ed25519")
                    .generatePublic(new X509EncodedKeySpec(x509));

            Signature verifier = Signature.getInstance("Ed25519");
            verifier.initVerify(publicKey);
            verifier.update(payload);
            return verifier.verify(signatureBytes);
        } catch (Exception error) {
            return false;
        }
    }
}
