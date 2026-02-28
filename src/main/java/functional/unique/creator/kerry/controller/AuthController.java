package functional.unique.creator.kerry.controller;

import functional.unique.creator.kerry.model.User;
import functional.unique.creator.kerry.security.JwtUtil;
import functional.unique.creator.kerry.service.UserService;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.crypto.bcrypt.BCrypt;

@RestController
@RequestMapping("/auth")
public class AuthController {

    private final UserService userService;
    private final JwtUtil jwtUtil;

    public AuthController(UserService userService, JwtUtil jwtUtil) {
        this.userService = userService;
        this.jwtUtil = jwtUtil;
    }

    public static class LoginRequest {
        public String phone;
        public String password;
    }

    @PostMapping("/login")
    public String login(@RequestBody LoginRequest req) {

        User user = userService.findByPhone(req.phone);

        if (user == null || !BCrypt.checkpw(req.password, user.getPasswordHash()))
            throw new RuntimeException("Invalid credentials");

        return jwtUtil.generateToken(user);
    }
}