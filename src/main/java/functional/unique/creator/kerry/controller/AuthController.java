package functional.unique.creator.kerry.controller;

import functional.unique.creator.kerry.dto.*;
import functional.unique.creator.kerry.service.AuthService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {

    private AuthService service;

    @PostMapping("/register")
    public Map<String, String> register(@RequestBody RegisterRequest req) {
        return (Map<String, String>) service.register(req);
    }

    @PostMapping("/login")
    public Map<String, String> login(@RequestBody LoginRequest req) {
        return (Map<String, String>) service.login(req);
    }
}