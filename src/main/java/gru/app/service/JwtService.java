package gru.app.service;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.security.KeyPair;
import java.util.Date;

@Service
@RequiredArgsConstructor
public class JwtService {

    private final KeyPair keyPair;

    public String generateToken(String userId) {

        long jwtExpirationMs = 86400000;
        return Jwts.builder()

                .setSubject(userId)

                .setIssuedAt(new Date())

                .setExpiration(
                        new Date(
                                System.currentTimeMillis()
                                        + jwtExpirationMs
                        )
                )

                .signWith(
                        keyPair.getPrivate(),
                        SignatureAlgorithm.ES256
                )

                .compact();
    }

    public String extractUserId(String token) {

        Claims claims =
                Jwts.parserBuilder()

                        .setSigningKey(
                                keyPair.getPublic()
                        )

                        .build()

                        .parseClaimsJws(token)

                        .getBody();

        return claims.getSubject();
    }
}