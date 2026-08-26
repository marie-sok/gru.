package gru.app.dto;

import lombok.Data;

@Data
public class SendMessageRequest {

    private String chatId;

    private String text;

    private String replyToMessageId;
}