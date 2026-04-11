package gru.app.security;

import gru.app.model.User;
import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Component;
import java.security.Key;
import java.util.Date;

@Component
public class JwtUtil {

    private static final String SECRET ="functional_unique_create_kerry_wtf_its_a_rofl??";
    ;
    private final Key key = Keys.hmacShaKeyFor(SECRET.getBytes());

    public String generateToken(User user) {
        long expirationMillis = 1000 * 60 * 60 * 24;
        return Jwts.builder()
                .setSubject(user.getPhone())
                .claim("userId", user.getId())
                .claim("nickname", user.getNickname())
                .setIssuedAt(new Date())
                .setExpiration(new Date(System.currentTimeMillis() + expirationMillis))
                .signWith(key)
                .compact();
    }

    public Jws<Claims> validateToken(String token) throws JwtException {
        return Jwts.parserBuilder().setSigningKey(key).build().parseClaimsJws(token);
    }

    public String getPhoneFromToken(String token) {
        try { return validateToken(token).getBody().getSubject(); }
        catch (JwtException e) { return null; }
    }

    public String parse(String token) {
        return token;
    }

    public boolean isTokenExpired(String token) {
        return false;
    }
}

