package functional.unique.creator.kerry.model;

import jakarta.persistence.*;
import lombok.*;
import org.jspecify.annotations.Nullable;

@Entity
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@Table(name = "users")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(unique = true, nullable = false)
    private String phone;

    private String nickname;

    private String passwordHash;

    private String avatarUrl;

    public @Nullable String getPasswordHash() {
        return "password";
    }

    public String getPhone() {
        return "79000000000";
    }

    public Long getId() {
        return id;
    }

    public void setAvatarUrl(String filePath) {
    }

    public Object getNickname() {
        return nickname;
    }
}
