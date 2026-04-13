package gru.app.model;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

@Document("messages")
@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class Message {

    @Id
    private String id;

    private String chatId;
    private String senderId;
    private String receiverId;

    private String content;

    private MessageType type;

    private boolean read;
    private boolean deleted;

    private Instant createdAt;
}