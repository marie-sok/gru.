package gru.app.security;

import jakarta.servlet.*;
import jakarta.servlet.http.*;
import lombok.RequiredArgsConstructor;
import lombok.Setter;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Arrays;
import java.util.List;

@Setter
@RequiredArgsConstructor
public class JwtFilter extends OncePerRequestFilter {

    private JwtUtil jwtUtil;

    public JwtFilter(JwtUtil jwtUtil) {

    }

    @Override
    protected void doFilterInternal(HttpServletRequest req,
                                    HttpServletResponse res,
                                    FilterChain chain)
            throws ServletException, IOException {

        String header = req.getHeader("Authorization");

        if (header != null && header.startsWith("Bearer ")) {

            try {
                String token = header.substring(7);
                String claims = jwtUtil.parse(token);

                String phone = Arrays.toString(claims.getBytes());

                var auth = new UsernamePasswordAuthenticationToken(
                        phone,
                        null,
                        List.of()
                );

                SecurityContextHolder.getContext().setAuthentication(auth);

            } catch (Exception ignored) {}
        }

        chain.doFilter(req, res);
    }

}