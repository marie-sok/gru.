package gru.app.dto;

import lombok.Data;

@Data
public class ChatMessage {
    private Long senderId;
    private Long receiverId;
    private String content;

    public ChatMessage(Long senderId, Long receiverId, String content) {
        this.senderId = senderId;
        this.receiverId = receiverId;
        this.content = content;
    }

}