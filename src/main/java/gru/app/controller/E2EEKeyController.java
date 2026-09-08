package gru.app.controller;

import gru.app.dto.E2EEKeyRequest;
import gru.app.dto.E2EEKeyResponse;
import gru.app.model.User;
import gru.app.repository.UserRepository;
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
