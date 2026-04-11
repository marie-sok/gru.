package gru.app.dto;

import lombok.Data;


import java.time.LocalDate;

@Data
public class RegisterRequest {
    @NotBlank
    private String phone;
    private String name;
    private String nickname;
    private boolean showNickname;
    @Email
    private String email;
    private LocalDate birthday;
    private String avatarUrl;
    @NotBlank
    private String password;
}

