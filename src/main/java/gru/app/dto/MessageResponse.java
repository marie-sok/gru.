package gru.app.dto;

import gru.app.model.MessageType;
import lombok.Data;

@Data
public class MessageResponse {
    private String id;
    private String chatId;
    private String senderId;
    private String content;
    private MessageType type;
    private boolean edited;
    private boolean deleted;
    private long createdAt;
    private long updatedAt;
}

