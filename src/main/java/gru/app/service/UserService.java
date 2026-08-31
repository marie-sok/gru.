package gru.app.service;

import gru.app.dto.UserResponse;
import gru.app.model.User;
import gru.app.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;

    public UserResponse getMe(String userId) {

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        return new UserResponse(
                user.getId(),
                user.getNickname(),
                user.getPhone()
        );
    }

    public List<UserResponse> search(String query) {

        return userRepository
                .findByNicknameContainingIgnoreCase(query)
                .stream()
                .map(user -> new UserResponse(
                        user.getId(),
                        user.getNickname(),
                        user.getPhone()
                ))
                .toList();
    }

    public User findByPhone(String phone) {
        return null;
    }
}