package gru.app.service;

import gru.app.model.User;
import gru.app.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository repository;

    @Cacheable(value = "users", key = "#phone")
    public User findByPhone(String phone) {
        return repository.findByPhone(phone).orElse(null);
    }

    public User save(User user) {
        return repository.save(user);
    }

    public User UserService(String token) {
        return null;
    }

    public List<User> search(String query) {
        return List.of();
    }

    public void block(String token, String id) {
    }

    public void unblock(String token, String id) {
    }

    public void setOnline(String token) {
    }

    public void setOffline(String token) {
    }

    public void setVisibility(String token, boolean visible) {
    }
}