package gru.app.service;

import gru.app.dto.AuthResponse;
import gru.app.dto.LoginRequest;
import gru.app.dto.RegisterRequest;
import gru.app.model.User;
import gru.app.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.server.ResponseStatusException;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
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
    void registerExistingPhoneReturnsConflict() {
        UserRepository repository = mock(UserRepository.class);
        JwtService jwtService = mock(JwtService.class);
        PasswordEncoder encoder = mock(PasswordEncoder.class);
        AuthService service = new AuthService(repository, jwtService, encoder);

        RegisterRequest request = new RegisterRequest();
        request.setPhone("+79990000001");
        request.setPassword("plain-password");
        request.setNickname("marie");

        when(repository.findByPhone(request.getPhone())).thenReturn(Optional.of(new User()));

        ResponseStatusException error = assertThrows(
                ResponseStatusException.class,
                () -> service.register(request)
        );

        assertEquals(HttpStatus.CONFLICT, error.getStatusCode());
        assertEquals("User already exists", error.getReason());
        verifyNoInteractions(jwtService);
    }

    @Test
    void loginRejectsWrongPasswordAsUnauthorized() {
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

        ResponseStatusException error = assertThrows(
                ResponseStatusException.class,
                () -> service.login(request)
        );

        assertEquals(HttpStatus.UNAUTHORIZED, error.getStatusCode());
        assertEquals("Invalid phone or password", error.getReason());
        verifyNoInteractions(jwtService);
        verify(repository, never()).save(existing);
    }

    @Test
    void loginUnknownPhoneUsesSameUnauthorizedResponse() {
        UserRepository repository = mock(UserRepository.class);
        JwtService jwtService = mock(JwtService.class);
        PasswordEncoder encoder = mock(PasswordEncoder.class);
        AuthService service = new AuthService(repository, jwtService, encoder);

        LoginRequest request = new LoginRequest();
        request.setPhone("+79990000002");
        request.setPassword("plain-password");

        when(repository.findByPhone(request.getPhone())).thenReturn(Optional.empty());

        ResponseStatusException error = assertThrows(
                ResponseStatusException.class,
                () -> service.login(request)
        );

        assertEquals(HttpStatus.UNAUTHORIZED, error.getStatusCode());
        assertEquals("Invalid phone or password", error.getReason());
        verifyNoInteractions(encoder, jwtService);
    }

    @Test
    void loginAcceptsAndMigratesLegacyPasswordHash() {
        UserRepository repository = mock(UserRepository.class);
        JwtService jwtService = mock(JwtService.class);
        PasswordEncoder encoder = mock(PasswordEncoder.class);
        AuthService service = new AuthService(repository, jwtService, encoder);

        User existing = new User();
        existing.setId("legacy-user");
        existing.setPhone("+79990000003");
        existing.setPassword(null);
        existing.setLegacyPasswordHash("legacy-bcrypt-hash");

        LoginRequest request = new LoginRequest();
        request.setPhone(existing.getPhone());
        request.setPassword("correct-password");

        when(repository.findByPhone(existing.getPhone())).thenReturn(Optional.of(existing));
        when(encoder.matches("correct-password", "legacy-bcrypt-hash")).thenReturn(true);
        when(repository.save(existing)).thenReturn(existing);
        when(jwtService.generateToken("legacy-user")).thenReturn("legacy-jwt");

        AuthResponse response = service.login(request);

        assertEquals("legacy-jwt", response.getToken());
        assertEquals("legacy-user", response.getUserId());
        assertEquals("legacy-bcrypt-hash", existing.getPassword());
        verify(repository).save(existing);
        verify(jwtService).generateToken("legacy-user");
    }
}
