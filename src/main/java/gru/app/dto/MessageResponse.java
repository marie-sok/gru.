package gru.app.dto;

import lombok.Data;

@Data
public class MessageResponse {

    private String id;

    private String chatId;

    private String senderId;

    private String content;

    private Long createdAt;
}