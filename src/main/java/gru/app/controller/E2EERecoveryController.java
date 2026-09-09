package gru.app.controller;

import gru.app.dto.E2EERecoveryBackupRequest;
import gru.app.dto.E2EERecoveryBackupResponse;
import gru.app.model.E2EERecoveryBackup;
import gru.app.model.User;
import gru.app.repository.E2EERecoveryBackupRepository;
import gru.app.repository.UserRepository;
import gru.app.security.E2EECryptoVerifier;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.Base64;

@RestController
@RequestMapping("/e2ee/recovery")
@RequiredArgsConstructor
public class E2EERecoveryController {

    static final String RECOVERY_VERSION = "gru-e2ee-recovery-v1";
    private static final int MAX_ENCRYPTED_BUNDLE_BYTES = 16 * 1024;

    private final E2EERecoveryBackupRepository backupRepository;
    private final UserRepository userRepository;
    private final E2EECryptoVerifier cryptoVerifier;

    @PutMapping("/me")
    public E2EERecoveryBackupResponse put(
            Authentication authentication,
            @RequestBody E2EERecoveryBackupRequest request
    ) {
        String userId = requireUserId(authentication);
        if (request == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Recovery backup is required");
        }
        if (!RECOVERY_VERSION.equals(request.version())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unsupported recovery version");
        }

        validateEncryptedBundle(request.encryptedBundle());
        validateSignature(request.signature());

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));
        if (user.getE2eeSigningPublicKey() == null || user.getE2eeSigningPublicKey().isBlank()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "E2EE identity must be registered first");
        }

        boolean valid = cryptoVerifier.verifyRecoveryBackup(
                user.getE2eeSigningPublicKey(),
                userId,
                request.version(),
                request.encryptedBundle(),
                request.signature()
        );
        if (!valid) {
            throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY, "Invalid recovery backup signature");
        }

        E2EERecoveryBackup backup = new E2EERecoveryBackup();
        backup.setUserId(userId);
        backup.setVersion(request.version());
        backup.setEncryptedBundle(request.encryptedBundle());
        backup.setSignature(request.signature());
        backup.setUpdatedAt(Instant.now());

        return response(backupRepository.save(backup));
    }

    @GetMapping("/me")
    public E2EERecoveryBackupResponse get(Authentication authentication) {
        String userId = requireUserId(authentication);
        E2EERecoveryBackup backup = backupRepository.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Recovery backup not found"));
        return response(backup);
    }

    private String requireUserId(Authentication authentication) {
        if (authentication == null
                || !authentication.isAuthenticated()
                || authentication.getName() == null
                || authentication.getName().isBlank()) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Unauthorized");
        }
        return authentication.getName();
    }

    private void validateEncryptedBundle(String encoded) {
        if (encoded == null || encoded.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "encryptedBundle is required");
        }
        try {
            byte[] bytes = Base64.getDecoder().decode(encoded);
            if (bytes.length < 64 || bytes.length > MAX_ENCRYPTED_BUNDLE_BYTES) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid recovery backup size");
            }
        } catch (IllegalArgumentException error) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "encryptedBundle must be base64");
        }
    }

    private void validateSignature(String encoded) {
        if (encoded == null || encoded.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "signature is required");
        }
        try {
            byte[] bytes = Base64.getDecoder().decode(encoded);
            if (bytes.length != 64) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "signature must be 64 bytes");
            }
        } catch (IllegalArgumentException error) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "signature must be base64");
        }
    }

    private E2EERecoveryBackupResponse response(E2EERecoveryBackup backup) {
        return new E2EERecoveryBackupResponse(
                backup.getVersion(),
                backup.getEncryptedBundle(),
                backup.getSignature(),
                backup.getUpdatedAt()
        );
    }
}
