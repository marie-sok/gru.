package gru.app.controller;

import gru.app.service.AuthService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/send-code")
    public void sendCode(@RequestParam String phone) {
        authService.sendCode(phone);
    }

    @PostMapping("/verify-code")
    public Map<String, String> verify(
            @RequestParam String phone,
            @RequestParam String code
    ) {
        return authService.verifyCode(phone, code);
    }
}