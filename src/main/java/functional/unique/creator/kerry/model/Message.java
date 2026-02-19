
package functional.unique.creator.kerry.model;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "messages")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Message {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String senderPhone;
    private String receiverPhone;
    private String content;

    private LocalDateTime timestamp;

    public void setSenderId(Long id) {
    }

    public Long getReceiverId() {
        return id;
    }
}
