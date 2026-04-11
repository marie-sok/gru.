package gru.app.model;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.LocalDate;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
@Document(collection = "users")
public class User {
    @Id
    private String id;
    private String phone;
    private String name;
    private String nickname;
    private boolean showNickname; // true если ник виден другим
    private String email;
    private String passwordHash;
    private String avatarUrl;
    private LocalDate birthday;
    private boolean verified;
}