package gru.app.service;

import gru.app.model.User;
import gru.app.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.List;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;

    public User findOrCreate(String phone) {

        return userRepository.findByPhone(phone)
                .orElseGet(() -> {
                    User u = new User();
                    u.setPhone(phone);
                    u.setName("New User");
                    u.setNickname("user_" + phone.substring(phone.length() - 4));
                    u.setBirthDate(LocalDate.now());
                    return userRepository.save(u);
                });
    }

    public User UserService(String token) {
        return null;
    }

    public List<User> search(String query) {
        return List.of();
    }

    public void setOnline(String token) {
    }

    public void setOffline(String token) {
    }

    public void setVisibility(String token, boolean visible) {
    }

    public void unblock(String token, String id) {
    }

    public void block(String token, String id) {

    }
}