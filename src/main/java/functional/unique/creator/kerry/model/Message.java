package functional.unique.creator.kerry.model;

import jakarta.persistence.*;
import lombok.*;

import java.nio.file.attribute.AclEntry;
import java.time.Instant;
import java.time.LocalDateTime;

@Entity
@Table(name = "messages")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Message {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private Long senderId;
    private Long receiverId;

    private String content;
    private String type;

    private boolean read;

    private Instant timestamp;

    public void setDeleted(boolean b) {
    }

    public AclEntry.Builder createdAt(LocalDateTime now) {
        return null;
    }
}