package functional.unique.creator.kerry.controller;

import functional.unique.creator.kerry.dto.AuthResponse;
import functional.unique.creator.kerry.dto.LoginRequest;
import functional.unique.creator.kerry.dto.RegisterRequest;
import functional.unique.creator.kerry.service.AuthService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;


@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/register")
    public AuthResponse register(@Valid @RequestBody RegisterRequest request) {
        return authService.register(request);
    }

    @PostMapping("/login")
    public AuthResponse login(@Valid @RequestBody LoginRequest request) {
        return authService.login(request);
    }
}