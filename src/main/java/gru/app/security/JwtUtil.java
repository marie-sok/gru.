package gru.app.security;

import gru.app.model.User;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.util.Date;

@Component
public class JwtUtil {

    private static final String SECRET =
            "functional_unique_create_kerry_wtf_its_a_rofl??";

    private final SecretKey key =
            Keys.hmacShaKeyFor(SECRET.getBytes());

    public String generateToken(User user) {

        long expirationMillis = 1000L * 60 * 60 * 24;

        return Jwts.builder()
                .subject(user.getPhone())
                .claim("userId", user.getId())
                .claim("nickname", user.getNickname())
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + expirationMillis))
                .signWith(key)
                .compact();
    }

    public Claims parseClaims(String token) {

        return Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    public String getPhoneFromToken(String token) {

        try {
            return parseClaims(token).getSubject();
        } catch (JwtException e) {
            return null;
        }
    }

    public String getUserIdFromToken(String token) {

        try {
            return parseClaims(token).get("userId", String.class);
        } catch (JwtException e) {
            return null;
        }
    }

    public String getNicknameFromToken(String token) {

        try {
            return parseClaims(token).get("nickname", String.class);
        } catch (JwtException e) {
            return null;
        }
    }

    public boolean isTokenValid(String token) {

        try {
            parseClaims(token);
            return true;
        } catch (JwtException e) {
            return false;
        }
    }

    public boolean isTokenExpired(String token) {

        try {

            Date expiration =
                    parseClaims(token).getExpiration();

            return expiration.before(new Date());

        } catch (JwtException e) {
            return true;
        }
    }

    public String parse(String token) {

        return getUserIdFromToken(token);
    }
}