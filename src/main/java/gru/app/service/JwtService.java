package gru.app.service;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Date;

@Service
public class JwtService {

    private static final String DEVELOPMENT_SECRET =
            "functional_unique_creator_kerry_wtf???_really??_fuck_rkn";

    private final SecretKey key;

    @Autowired
    public JwtService(
            @Value("${gru.security.jwt-secret:${GRU_JWT_SECRET:}}") String configuredSecret,
            Environment environment
    ) {
        boolean production = Arrays.stream(environment.getActiveProfiles())
                .anyMatch("prod"::equalsIgnoreCase);

        this.key = buildKey(resolveSecret(configuredSecret, production));
    }

    // Kept for focused unit tests and local non-Spring construction.
    JwtService(String configuredSecret) {
        this.key = buildKey(resolveSecret(configuredSecret, false));
    }

    private static String resolveSecret(String configuredSecret, boolean production) {
        String clean = configuredSecret == null ? "" : configuredSecret.trim();

        if (clean.isBlank()) {
            if (production) {
                throw new IllegalStateException(
                        "GRU_JWT_SECRET must be configured when the prod profile is active"
                );
            }

            clean = DEVELOPMENT_SECRET;
        }

        if (clean.getBytes(StandardCharsets.UTF_8).length < 32) {
            throw new IllegalStateException("GRU_JWT_SECRET must contain at least 32 bytes");
        }

        return clean;
    }

    private static SecretKey buildKey(String secret) {
        return Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
    }

    public String generateToken(String userId) {
        long expiration = 1000L * 60 * 60 * 24;

        return Jwts.builder()
                .subject(userId)
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + expiration))
                .signWith(key)
                .compact();
    }

    public String extractUserId(String token) {
        Claims claims = Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();

        return claims.getSubject();
    }

    public boolean isValid(String token) {
        try {
            Jwts.parser()
                    .verifyWith(key)
                    .build()
                    .parseSignedClaims(token);
            return true;
        } catch (JwtException e) {
            return false;
        }
    }
}
