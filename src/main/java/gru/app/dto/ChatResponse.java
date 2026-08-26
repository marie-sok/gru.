package gru.app.dto;

import java.time.Instant;
import java.util.List;

public record ChatResponse(
        String id,
        List<ChatParticipantResponse> participants,
        Instant createdAt
) {
}