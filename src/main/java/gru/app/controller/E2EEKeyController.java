package gru.app.controller;

import gru.app.dto.E2EEKeyRequest;
import gru.app.dto.E2EEKeyResponse;
import gru.app.dto.E2EEKeyRotationRequest;
import gru.app.model.User;
import gru.app.repository.UserRepository;
import gru.app.security.E2EECryptoVerifier;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.Base64;

@RestController
@RequestMapping("/e2ee/keys")
@RequiredArgsConstructor
public class E2EEKeyController {

    private final UserRepository userRepository;
    private final E2EECryptoVerifier cryptoVerifier;

    @PutMapping("/me")
    public E2EEKeyResponse publish(
            Authentication authentication,
            @RequestBody E2EEKeyRequest request
    ) {
        if (request == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Key request is required");
        }

        validateKey(request.keyAgreementPublicKey(), "keyAgreementPublicKey");
        validateKey(request.signingPublicKey(), "signingPublicKey");

        User user = requireUser(authentication.getName());

        boolean hasExistingKeys = user.getE2eeKeyAgreementPublicKey() != null
                && user.getE2eeSigningPublicKey() != null;
        if (hasExistingKeys) {
            boolean sameAgreement = user.getE2eeKeyAgreementPublicKey()
                    .equals(request.keyAgreementPublicKey());
            boolean sameSigning = user.getE2eeSigningPublicKey()
                    .equals(request.signingPublicKey());

            if (!sameAgreement || !sameSigning) {
                throw new ResponseStatusException(
                        HttpStatus.CONFLICT,
                        "E2EE identity already exists; signed rotation is required"
                );
            }
            return response(user);
        }

        user.setE2eeKeyAgreementPublicKey(request.keyAgreementPublicKey());
        user.setE2eeSigningPublicKey(request.signingPublicKey());
        user.setE2eeKeyUpdatedAt(Instant.now());
        user = userRepository.save(user);
        return response(user);
    }

    @PostMapping("/me/rotate")
    public E2EEKeyResponse rotate(
            Authentication authentication,
            @RequestBody E2EEKeyRotationRequest request
    ) {
        if (request == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Rotation request is required");
        }

        validateKey(request.keyAgreementPublicKey(), "keyAgreementPublicKey");
        validateKey(request.signingPublicKey(), "signingPublicKey");
        validateSignature(request.rotationSignature());

        User user = requireUser(authentication.getName());
        if (user.getE2eeSigningPublicKey() == null || user.getE2eeKeyAgreementPublicKey() == null) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT,
                    "No existing E2EE identity; publish keys first"
            );
        }

        if (!cryptoVerifier.verifyKeyRotation(
                user.getE2eeSigningPublicKey(),
                user.getId(),
                request.keyAgreementPublicKey(),
                request.signingPublicKey(),
                request.rotationSignature()
        )) {
            throw new ResponseStatusException(
                    HttpStatus.UNPROCESSABLE_ENTITY,
                    "Invalid E2EE key rotation signature"
            );
        }

        user.setE2eeKeyAgreementPublicKey(request.keyAgreementPublicKey());
        user.setE2eeSigningPublicKey(request.signingPublicKey());
        user.setE2eeKeyUpdatedAt(Instant.now());
        user = userRepository.save(user);
        return response(user);
    }

    @GetMapping("/{userId}")
    public E2EEKeyResponse get(
            Authentication authentication,
            @PathVariable String userId
    ) {
        requireUser(authentication.getName());
        User user = requireUser(userId);
        if (user.getE2eeKeyAgreementPublicKey() == null
                || user.getE2eeSigningPublicKey() == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "E2EE keys are not registered");
        }
        return response(user);
    }

    private void validateKey(String encoded, String field) {
        if (encoded == null || encoded.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, field + " is required");
        }
        try {
            byte[] decoded = Base64.getDecoder().decode(encoded);
            if (decoded.length != 32) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, field + " must be 32 bytes");
            }
        } catch (IllegalArgumentException error) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, field + " must be base64");
        }
    }

    private void validateSignature(String encoded) {
        if (encoded == null || encoded.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "rotationSignature is required");
        }
        try {
            byte[] decoded = Base64.getDecoder().decode(encoded);
            if (decoded.length != 64) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "rotationSignature must be 64 bytes");
            }
        } catch (IllegalArgumentException error) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "rotationSignature must be base64");
        }
    }

    private User requireUser(String userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));
    }

    private E2EEKeyResponse response(User user) {
        return new E2EEKeyResponse(
                user.getId(),
                user.getE2eeKeyAgreementPublicKey(),
                user.getE2eeSigningPublicKey(),
                user.getE2eeKeyUpdatedAt()
        );
    }
}
