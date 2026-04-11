package gru.app.model;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;
import java.util.List;

@Document(collection = "chats")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Chat {

    @Id
    private String id;

    private List<String> participants;

    private String lastMessage;
    private Instant lastMessageTime;
}