package gru.app.dto;

public record ReportUserRequest(
        String chatId,
        String reason,
        String details
) {}
