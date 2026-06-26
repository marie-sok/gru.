package gru.app.model;

import lombok.Data;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

@Document(collection = "messages")
@Data
public class Message {

    @Id
    private String id;

    private String chatId;

    private String senderId;

    private String text;

    private Instant createdAt;

    public Long getReceiverId() {
        return 0L;
    }
}