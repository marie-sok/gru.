package functional.unique.creator.kerry.dto;

import lombok.Data;

@Data
public class AuthResponse {
    private String token;
    private String userId;
}