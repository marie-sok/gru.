package gru.app.model;

import lombok.Data;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

@Document(collection = "abuse_reports")
@Data
public class AbuseReport {
    @Id
    private String id;
    private String reporterId;
    private String targetUserId;
    private String chatId;
    private String reason;
    private String details;
    private String status;
    private Instant createdAt;
}
