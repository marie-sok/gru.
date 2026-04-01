package functional.unique.creator.kerry.model;

import jakarta.persistence.*;
import lombok.*;
import java.util.Date;

@Entity
@Table(name = "messages")
@Data
@NoArgsConstructor
@AllArgsConstructor
@RequiredArgsConstructor
public class Message {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NonNull
    private Long senderId;

    @NonNull
    private Long receiverId;

    @NonNull
    @Lob
    private String content;

    @NonNull
    private String contentType;
    private boolean read;

    private Date timestamp;
}