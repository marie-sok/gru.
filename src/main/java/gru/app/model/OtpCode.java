package gru.app.model;

import lombok.*;

import java.time.Instant;

@Getter
@Setter
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class OtpCode {

    private String phone;
    private String code;
    private Instant expiresAt;
}