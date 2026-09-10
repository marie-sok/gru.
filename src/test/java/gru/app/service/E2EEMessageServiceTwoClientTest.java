package gru.app.service;

import gru.app.dto.E2EEMessageRequest;
import gru.app.model.Chat;
import gru.app.model.Message;
import gru.app.model.User;
import gru.app.repository.ChatRepository;
import gru.app.repository.MessageRepository;
import gru.app.repository.UserRepository;
import gru.app.security.E2EECryptoVerifier;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.MessageDigest;
import java.security.Signature;
import java.util.Base64;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class E2EEMessageServiceTwoClientTest {

    private MessageRepository messageRepository;
    private ChatRepository chatRepository;
    private UserRepository userRepository;
    private E2EEMessageService service;

    private User alice;
    private User bob;
    private KeyPair aliceSigning;
    private KeyPair bobSigning;

    @BeforeEach
    void setUp() throws Exception {
        messageRepository = mock(MessageRepository.class);
        chatRepository = mock(ChatRepository.class);
        userRepository = mock(UserRepository.class);

        service = new E2EEMessageService(
                messageRepository,
                chatRepository,
                userRepository,
                new E2EECryptoVerifier()
        );

        aliceSigning = KeyPairGenerator.getInstance("Ed25519").generateKeyPair();
        bobSigning = KeyPairGenerator.getInstance("Ed25519").generateKeyPair();

        alice = user("alice", aliceSigning);
        bob = user("bob", bobSigning);

        Chat chat = new Chat();
        chat.setId("chat-1");
        chat.setParticipants(List.of("alice", "bob"));

        when(chatRepository.findById("chat-1")).thenReturn(Optional.of(chat));
        when(userRepository.findById("alice")).thenReturn(Optional.of(alice));
        when(userRepository.findById("bob")).thenReturn(Optional.of(bob));
        when(messageRepository.findFirstBySenderIdAndE2eeClientMessageId(any(), any()))
                .thenReturn(Optional.empty());

        AtomicInteger ids = new AtomicInteger();
        when(messageRepository.save(any(Message.class))).thenAnswer(invocation -> {
            Message message = invocation.getArgument(0);
            if (message.getId() == null) {
                message.setId("m-" + ids.incrementAndGet());
            }
            return message;
        });
    }

    @Test
    void twoIndependentUsersCanExchangeSignedV2CiphertextBothDirections() throws Exception {
        Message aliceToBob = service.send(
                "alice",
                request("alice", "bob", aliceSigning, "cipher-a-to-b", "recovery-a")
        );

        Message bobToAlice = service.send(
                "bob",
                request("bob", "alice", bobSigning, "cipher-b-to-a", "recovery-b")
        );

        assertThat(aliceToBob.getSenderId()).isEqualTo("alice");
        assertThat(aliceToBob.getReceiverId()).isEqualTo("bob");
        assertThat(aliceToBob.getText()).isEmpty();
        assertThat(aliceToBob.getEncryptionVersion()).isEqualTo("gru-e2ee-v2");
        assertThat(aliceToBob.getEncryptedPayload()).isNotBlank();
        assertThat(aliceToBob.getSenderRecoveryEncryptedPayload()).isNotBlank();
        assertThat(aliceToBob.getSenderSigningPublicKey()).isEqualTo(alice.getE2eeSigningPublicKey());
        assertThat(aliceToBob.getSenderKeyAgreementPublicKey()).isEqualTo(alice.getE2eeKeyAgreementPublicKey());

        assertThat(bobToAlice.getSenderId()).isEqualTo("bob");
        assertThat(bobToAlice.getReceiverId()).isEqualTo("alice");
        assertThat(bobToAlice.getText()).isEmpty();
        assertThat(bobToAlice.getEncryptionVersion()).isEqualTo("gru-e2ee-v2");
        assertThat(bobToAlice.getEncryptedPayload()).isNotBlank();
        assertThat(bobToAlice.getSenderRecoveryEncryptedPayload()).isNotBlank();
        assertThat(bobToAlice.getSenderSigningPublicKey()).isEqualTo(bob.getE2eeSigningPublicKey());
        assertThat(bobToAlice.getSenderKeyAgreementPublicKey()).isEqualTo(bob.getE2eeKeyAgreementPublicKey());
    }

    @Test
    void serverDerivesReceiverFromChatMembershipInsteadOfTrustingClientMetadata() throws Exception {
        E2EEMessageRequest request = request(
                "alice",
                "bob",
                aliceSigning,
                "cipher-membership",
                "recovery-membership"
        );

        Message saved = service.send("alice", request);

        assertThat(saved.getChatId()).isEqualTo("chat-1");
        assertThat(saved.getSenderId()).isEqualTo("alice");
        assertThat(saved.getReceiverId()).isEqualTo("bob");
    }

    private User user(String id, KeyPair signingPair) throws Exception {
        User user = new User();
        user.setId(id);
        user.setNickname(id);
        user.setE2eeSigningPublicKey(rawPublicKeyBase64(signingPair));
        user.setE2eeKeyAgreementPublicKey(Base64.getEncoder().encodeToString(random32(id)));
        return user;
    }

    private E2EEMessageRequest request(
            String senderId,
            String receiverId,
            KeyPair signingPair,
            String recipientCipherSeed,
            String recoveryCipherSeed
    ) throws Exception {
        String version = "gru-e2ee-v2";
        String chatId = "chat-1";
        String clientMessageId = UUID.randomUUID().toString();
        String recipientEphemeral = Base64.getEncoder().encodeToString(random32("recipient-" + clientMessageId));
        String recoveryEphemeral = Base64.getEncoder().encodeToString(random32("recovery-" + clientMessageId));
        String recipientCipher = Base64.getEncoder().encodeToString(
                fixedCipher(recipientCipherSeed)
        );
        String recoveryCipher = Base64.getEncoder().encodeToString(
                fixedCipher(recoveryCipherSeed)
        );
        String signingPublicKey = rawPublicKeyBase64(signingPair);
        String fingerprint = sha256Hex(Base64.getDecoder().decode(signingPublicKey));

        String canonical = String.join("|",
                version,
                chatId,
                senderId,
                receiverId,
                clientMessageId,
                recipientEphemeral,
                recipientCipher,
                recoveryEphemeral,
                recoveryCipher,
                fingerprint
        );

        Signature signer = Signature.getInstance("Ed25519");
        signer.initSign(signingPair.getPrivate());
        signer.update(canonical.getBytes(StandardCharsets.UTF_8));
        String signature = Base64.getEncoder().encodeToString(signer.sign());

        E2EEMessageRequest request = new E2EEMessageRequest();
        request.setChatId(chatId);
        request.setClientMessageId(clientMessageId);
        request.setEncryptedPayload(recipientCipher);
        request.setEncryptionVersion(version);
        request.setSenderEphemeralPublicKey(recipientEphemeral);
        request.setSenderRecoveryEncryptedPayload(recoveryCipher);
        request.setSenderRecoveryEphemeralPublicKey(recoveryEphemeral);
        request.setSignature(signature);
        request.setSenderKeyFingerprint(fingerprint);
        return request;
    }

    private byte[] fixedCipher(String seed) {
        byte[] source = seed.getBytes(StandardCharsets.UTF_8);
        byte[] out = new byte[48];
        for (int i = 0; i < out.length; i++) {
            out[i] = source[i % source.length];
        }
        return out;
    }

    private byte[] random32(String seed) throws Exception {
        byte[] digest = MessageDigest.getInstance("SHA-256")
                .digest(seed.getBytes(StandardCharsets.UTF_8));
        byte[] out = new byte[32];
        System.arraycopy(digest, 0, out, 0, 32);
        return out;
    }

    private String sha256Hex(byte[] value) throws Exception {
        byte[] digest = MessageDigest.getInstance("SHA-256").digest(value);
        StringBuilder builder = new StringBuilder(digest.length * 2);
        for (byte b : digest) {
            builder.append(String.format("%02x", b));
        }
        return builder.toString();
    }

    private String rawPublicKeyBase64(KeyPair pair) {
        byte[] encoded = pair.getPublic().getEncoded();
        byte[] raw = new byte[32];
        System.arraycopy(encoded, encoded.length - raw.length, raw, 0, raw.length);
        return Base64.getEncoder().encodeToString(raw);
    }
}
