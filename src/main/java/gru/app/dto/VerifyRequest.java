package gru.app.dto;

import lombok.Data;

@Data
public class VerifyRequest {
    private String phone;
    private String code;
}