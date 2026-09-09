package gru.app.dto;

public record E2EEKeyRequest(
        String keyAgreementPublicKey,
        String signingPublicKey
) {}
