package gru.app.dto;

public record E2EEKeyRotationRequest(
        String keyAgreementPublicKey,
        String signingPublicKey,
        String rotationSignature
) {}
