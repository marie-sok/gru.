package functional.unique.creator.kerry.controller;

import functional.unique.creator.kerry.model.User;
import functional.unique.creator.kerry.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {

    private final UserService service;

    @PostMapping("/register")
    public User register(@RequestParam String phone,
                         @RequestParam String nickname,
                         @RequestParam String password) {
        return service.register(phone, nickname, password);
    }
}
