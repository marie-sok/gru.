package gru.app.model;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "messages")
public class Message<T> {

    @Id
    private String id;

    private String chatId;

    private String senderId;

    private String content;

    private MessageType type;

    private boolean read;

    private boolean deleted;

    private Instant createdAt;

    public T getReceiverId() {
        return null;
    }
}