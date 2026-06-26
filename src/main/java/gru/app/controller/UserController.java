package gru.app.controller;

import gru.app.dto.UserResponse;
import gru.app.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping("/me")
    public UserResponse me(
            Authentication authentication
    ) {

        String userId = authentication.getName();

        return userService.getMe(userId);
    }

    @GetMapping("/search")
    public List<UserResponse> search(
            @RequestParam String query
    ) {

        return userService.search(query);
    }
}