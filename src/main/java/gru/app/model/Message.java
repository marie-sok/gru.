package gru.app.model;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

@Document(collection = "messages")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Message {

    @Id
    private String id;

    private String chatId;
    private String senderId;

    private String content;
    private MessageType type;

    private boolean edited;
    private boolean deleted;

    private Instant createdAt;
    private Instant updatedAt;

    public Long getReceiverId() {
        return 0L;
    }
}

