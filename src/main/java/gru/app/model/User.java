package gru.app.model;

import lombok.Data;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.util.HashSet;
import java.util.Set;

@Document(collection = "users")
@Data
public class User {

    @Id
    private String id;

    private String phone;

    private String password;

    private String nickname;

    private Set<String> blockedUserIds = new HashSet<>();
}
