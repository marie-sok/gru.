package gru.app.service;

import gru.app.dto.AuthResponse;
import gru.app.dto.LoginRequest;
import gru.app.dto.RegisterRequest;
import gru.app.model.User;
import gru.app.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
@RequiredArgsConstructor
public class AuthService {

    private static final String INVALID_CREDENTIALS = "Invalid phone or password";

    private final UserRepository userRepository;
    private final JwtService jwtService;
    private final PasswordEncoder passwordEncoder;

    public AuthResponse register(RegisterRequest request) {

        if (userRepository.findByPhone(request.getPhone()).isPresent()) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT,
                    "User already exists"
            );
        }

        User user = new User();

        user.setPhone(request.getPhone());

        user.setPassword(
                passwordEncoder.encode(request.getPassword())
        );

        user.setNickname(request.getNickname());

        user = userRepository.save(user);

        String token =
                jwtService.generateToken(user.getId());

        return new AuthResponse(
                token,
                user.getId()
        );
    }

    public AuthResponse login(LoginRequest request) {

        User user = userRepository.findByPhone(
                        request.getPhone()
                )
                .orElseThrow(() -> unauthorizedCredentials());

        String encodedPassword = user.getPassword();
        boolean usesLegacyPasswordField =
                encodedPassword == null || encodedPassword.isBlank();

        if (usesLegacyPasswordField) {
            encodedPassword = user.getLegacyPasswordHash();
        }

        if (encodedPassword == null || encodedPassword.isBlank() ||
                !passwordEncoder.matches(
                        request.getPassword(),
                        encodedPassword
                )) {
            throw unauthorizedCredentials();
        }

        // Accounts created by the original backend stored their bcrypt hash in
        // Mongo field "passwordHash". Copy that same hash into the current field
        // only after a successful password proof; no password is reset or exposed.
        if (usesLegacyPasswordField) {
            user.setPassword(encodedPassword);
            userRepository.save(user);
        }

        String token =
                jwtService.generateToken(user.getId());

        return new AuthResponse(
                token,
                user.getId()
        );
    }

    private ResponseStatusException unauthorizedCredentials() {
        return new ResponseStatusException(
                HttpStatus.UNAUTHORIZED,
                INVALID_CREDENTIALS
        );
    }
}
