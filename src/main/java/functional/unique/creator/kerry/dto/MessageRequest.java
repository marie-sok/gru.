package functional.unique.creator.kerry.dto;

import functional.unique.creator.kerry.model.MessageType;
import lombok.Data;

@Data
public class MessageRequest {
    private String chatId;
    private String content;
    private MessageType type;
}

