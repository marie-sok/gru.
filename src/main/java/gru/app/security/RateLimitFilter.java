package gru.app.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Clock;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

@Component
public class RateLimitFilter extends OncePerRequestFilter {

    private final boolean enabled;
    private final Limit authLimit;
    private final Limit websocketLimit;
    private final Limit mediaLimit;
    private final Limit apiLimit;
    private final Clock clock;

    private final Map<String, Window> windows = new ConcurrentHashMap<>();
    private final AtomicLong cleanupTicker = new AtomicLong();

    @Autowired
    public RateLimitFilter(
            @Value("${gru.security.rate-limit.enabled:true}") boolean enabled,
            @Value("${gru.security.rate-limit.auth.requests:10}") int authRequests,
            @Value("${gru.security.rate-limit.auth.window-seconds:60}") long authWindowSeconds,
            @Value("${gru.security.rate-limit.websocket.requests:30}") int websocketRequests,
            @Value("${gru.security.rate-limit.websocket.window-seconds:60}") long websocketWindowSeconds,
            @Value("${gru.security.rate-limit.media.requests:40}") int mediaRequests,
            @Value("${gru.security.rate-limit.media.window-seconds:60}") long mediaWindowSeconds,
            @Value("${gru.security.rate-limit.api.requests:240}") int apiRequests,
            @Value("${gru.security.rate-limit.api.window-seconds:60}") long apiWindowSeconds
    ) {
        this(enabled,
                new Limit(authRequests, authWindowSeconds),
                new Limit(websocketRequests, websocketWindowSeconds),
                new Limit(mediaRequests, mediaWindowSeconds),
                new Limit(apiRequests, apiWindowSeconds),
                Clock.systemUTC());
    }

    RateLimitFilter(
            boolean enabled,
            Limit authLimit,
            Limit websocketLimit,
            Limit mediaLimit,
            Limit apiLimit,
            Clock clock
    ) {
        this.enabled = enabled;
        this.authLimit = authLimit;
        this.websocketLimit = websocketLimit;
        this.mediaLimit = mediaLimit;
        this.apiLimit = apiLimit;
        this.clock = clock;
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {

        if (!enabled || "OPTIONS".equalsIgnoreCase(request.getMethod())) {
            filterChain.doFilter(request, response);
            return;
        }

        String path = request.getRequestURI();
        Limit limit = selectLimit(path);
        String clientKey = normalizedClientAddress(request);
        String bucketKey = limit.name() + ":" + clientKey;
        long now = clock.millis();

        Window window = windows.compute(bucketKey, (key, current) -> {
            if (current == null || now - current.startedAtMillis >= limit.windowMillis()) {
                return new Window(now, new AtomicInteger(1));
            }
            current.counter.incrementAndGet();
            return current;
        });

        int used = window.counter.get();
        int remaining = Math.max(0, limit.requests() - used);
        long retryAfterSeconds = Math.max(
                1,
                (limit.windowMillis() - Math.max(0, now - window.startedAtMillis) + 999) / 1000
        );

        response.setHeader("X-RateLimit-Limit", Integer.toString(limit.requests()));
        response.setHeader("X-RateLimit-Remaining", Integer.toString(remaining));

        cleanupIfNeeded(now);

        if (used > limit.requests()) {
            response.setStatus(429);
            response.setContentType("application/json");
            response.setCharacterEncoding("UTF-8");
            response.setHeader("Retry-After", Long.toString(retryAfterSeconds));
            response.getWriter().write("{\"error\":\"rate_limited\",\"retryAfterSeconds\":" + retryAfterSeconds + "}");
            return;
        }

        filterChain.doFilter(request, response);
    }

    private Limit selectLimit(String path) {
        if (path.startsWith("/auth/")) {
            return authLimit.withName("auth");
        }
        if (path.startsWith("/ws")) {
            return websocketLimit.withName("websocket");
        }
        if (path.startsWith("/media")) {
            return mediaLimit.withName("media");
        }
        return apiLimit.withName("api");
    }

    private String normalizedClientAddress(HttpServletRequest request) {
        String remote = request.getRemoteAddr();
        if (remote == null || remote.isBlank()) {
            return "unknown";
        }
        return remote.trim();
    }

    private void cleanupIfNeeded(long now) {
        if ((cleanupTicker.incrementAndGet() & 1023L) != 0L) {
            return;
        }

        long maxWindow = Math.max(
                Math.max(authLimit.windowMillis(), websocketLimit.windowMillis()),
                Math.max(mediaLimit.windowMillis(), apiLimit.windowMillis())
        );
        long staleBefore = now - (maxWindow * 2);
        windows.entrySet().removeIf(entry -> entry.getValue().startedAtMillis < staleBefore);
    }

    record Limit(String name, int requests, long windowMillis) {
        Limit(int requests, long windowSeconds) {
            this("", Math.max(1, requests), Math.max(1, windowSeconds) * 1000L);
        }

        Limit withName(String newName) {
            return new Limit(newName, requests, windowMillis);
        }
    }

    private record Window(long startedAtMillis, AtomicInteger counter) {
    }
}
