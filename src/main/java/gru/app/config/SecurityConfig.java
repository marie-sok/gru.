package gru.app.config;

import gru.app.security.JwtFilter;
import jakarta.servlet.DispatcherType;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.security.web.header.writers.StaticHeadersWriter;

@Configuration
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtFilter jwtFilter;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {

        return http
                .csrf(AbstractHttpConfigurer::disable)

                .sessionManagement(session ->
                        session.sessionCreationPolicy(
                                SessionCreationPolicy.STATELESS
                        )
                )

                .headers(headers -> headers
                        // GRU does not intentionally expose web resources for
                        // embedding by unrelated origins. Make that boundary
                        // explicit for browsers and passive security scanners.
                        .addHeaderWriter(
                                new StaticHeadersWriter(
                                        "Cross-Origin-Resource-Policy",
                                        "same-origin"
                                )
                        )
                )

                .authorizeHttpRequests(auth -> auth

                        // Preserve the original controller status (404/409/422/etc.)
                        // when Spring Boot performs its internal ERROR dispatch.
                        // Without this, the secondary /error dispatch can be denied
                        // as anonymous and incorrectly mask the real response as 403.
                        .dispatcherTypeMatchers(DispatcherType.ERROR).permitAll()

                        .requestMatchers(
                                "/",
                                "/auth/**",
                                "/ws",
                                "/ws/**",
                                "/privacy",
                                "/support",
                                "/health",
                                "/ready",
                                "/actuator/health"
                        ).permitAll()

                        .anyRequest().authenticated()
                )

                .addFilterBefore(
                        jwtFilter,
                        UsernamePasswordAuthenticationFilter.class
                )

                .build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
