package gru.app.model;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@Document(collection = "messages")
public class Message<T> {

    @Id
    private String id;

    private String chatId;

    private String senderId;

    private String text;

    private Instant createdAt;

    private boolean deleted;

    public void setContent(String newContent) {
    }

    public T getReceiverId() {
        return null;
    }
}