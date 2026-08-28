package gru.app.dto;

import java.util.Map;

public record UnreadCountsResponse(
        Map<String, Long> chats,
        long total
) {
}