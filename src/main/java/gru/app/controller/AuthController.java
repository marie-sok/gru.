package gru.app.controller;

import gru.app.dto.AuthResponse;
import gru.app.dto.LoginRequest;
import gru.app.dto.VerifyRequest;
import gru.app.service.AuthService;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/send")
    public void send(@RequestBody LoginRequest req) {
        authService.sendCode(req.getPhone());
    }

    @PostMapping("/verify")
    public AuthResponse verify(@RequestBody VerifyRequest req) {
        return authService.verify(req);
    }
}