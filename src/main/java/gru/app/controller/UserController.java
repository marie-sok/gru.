package gru.app.controller;

import gru.app.dto.UserResponse;
import gru.app.model.User;
import gru.app.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/users")
@RequiredArgsConstructor
public class UserController {

    private final UserRepository userRepository;

    @GetMapping("/me")
    public UserResponse me(
            Authentication authentication
    ) {

        String userId =
                authentication.getName();

        User user =
                userRepository.findById(userId)
                        .orElseThrow();

        return new UserResponse(
                user.getId(),
                user.getPhone(),
                user.getNickname()
        );
    }
}