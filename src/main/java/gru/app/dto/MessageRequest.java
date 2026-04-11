package gru.app.dto;

import gru.app.model.MessageType;
import lombok.Data;

@Data
public class MessageRequest {
    private String chatId;
    private String content;
    private MessageType type;
}

