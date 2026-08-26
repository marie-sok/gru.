package gru.app.controller;

import gru.app.dto.UserSearchResponse;
import gru.app.model.User;
import gru.app.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/users")
@RequiredArgsConstructor
public class UserController {

    private final UserRepository userRepository;

    @GetMapping("/search")
    public List<UserSearchResponse> search(
            Authentication authentication,
            @RequestParam String nickname
    ) {

        String currentUserId =
                authentication.getName();

        String query =
                nickname == null
                        ? ""
                        : nickname.trim();

        if (query.length() < 2) {
            return List.of();
        }

        return userRepository
                .findByNicknameContainingIgnoreCase(query)
                .stream()
                .filter(user ->
                        !user.getId().equals(currentUserId)
                )
                .limit(20)
                .map(this::toResponse)
                .toList();
    }

    private UserSearchResponse toResponse(
            User user
    ) {

        return new UserSearchResponse(
                user.getId(),
                user.getNickname()
        );
    }
}