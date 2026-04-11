package gru.app.model;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;
import java.time.LocalDate;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "users")
public class User {

    @Id
    private String id;

    private String phone;

    private String passwordHash;

    private boolean verified;

    private Instant createdAt;

    public void setName(String newUser) {

    }

    public void setNickname(String s) {
    }

    public void setBirthDate(LocalDate now) {
    }
}