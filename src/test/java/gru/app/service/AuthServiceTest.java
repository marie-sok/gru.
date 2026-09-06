package gru.app.service;

import gru.app.dto.AuthResponse;
import gru.app.dto.LoginRequest;
import gru.app.dto.RegisterRequest;
import gru.app.model.User;
import gru.app.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AuthServiceTest {

    @Test
    void registerHashesPasswordAndReturnsToken() {
        UserRepository repository = mock(UserRepository.class);
        JwtService jwtService = mock(JwtService.class);
        PasswordEncoder encoder = mock(PasswordEncoder.class);
        AuthService service = new AuthService(repository, jwtService, encoder);

        RegisterRequest request = new RegisterRequest();
        request.setPhone("+79990000001");
        request.setPassword("plain-password");
        request.setNickname("marie");

        when(repository.findByPhone(request.getPhone())).thenReturn(Optional.empty());
        when(encoder.encode("plain-password")).thenReturn("encoded-password");
        when(repository.save(any(User.class))).thenAnswer(invocation -> {
            User saved = invocation.getArgument(0);
            saved.setId("user-1");
            return saved;
        });
        when(jwtService.generateToken("user-1")).thenReturn("jwt-token");

        AuthResponse response = service.register(request);

        assertEquals("jwt-token", response.getToken());
        assertEquals("user-1", response.getUserId());
        verify(encoder).encode("plain-password");
        verify(repository).save(any(User.class));
    }

    @Test
    void loginRejectsWrongPassword() {
        UserRepository repository = mock(UserRepository.class);
        JwtService jwtService = mock(JwtService.class);
        PasswordEncoder encoder = mock(PasswordEncoder.class);
        AuthService service = new AuthService(repository, jwtService, encoder);

        User existing = new User();
        existing.setId("user-1");
        existing.setPhone("+79990000001");
        existing.setPassword("encoded-password");

        LoginRequest request = new LoginRequest();
        request.setPhone(existing.getPhone());
        request.setPassword("wrong-password");

        when(repository.findByPhone(existing.getPhone())).thenReturn(Optional.of(existing));
        when(encoder.matches("wrong-password", "encoded-password")).thenReturn(false);

        RuntimeException error = assertThrows(
                RuntimeException.class,
                () -> service.login(request)
        );

        assertEquals("Wrong password", error.getMessage());
    }
}
