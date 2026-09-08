package gru.app.dto;

import java.time.Instant;

public record E2EEKeyResponse(
        String userId,
        String keyAgreementPublicKey,
        String signingPublicKey,
        Instant updatedAt
) {}
