package gru.app.security;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import static org.assertj.core.api.Assertions.assertThat;

class RateLimitFilterTest {

    private final Clock clock = Clock.fixed(
            Instant.parse("2026-09-09T12:00:00Z"),
            ZoneOffset.UTC
    );

    @Test
    void blocksAuthRequestsAfterLimit() throws Exception {
        RateLimitFilter filter = filterWithAuthLimit(2);

        MockHttpServletResponse first = invoke(filter, "POST", "/auth/login");
        MockHttpServletResponse second = invoke(filter, "POST", "/auth/login");
        MockHttpServletResponse third = invoke(filter, "POST", "/auth/login");

        assertThat(first.getStatus()).isEqualTo(200);
        assertThat(second.getStatus()).isEqualTo(200);
        assertThat(third.getStatus()).isEqualTo(429);
        assertThat(third.getHeader("Retry-After")).isEqualTo("60");
        assertThat(third.getContentAsString()).contains("rate_limited");
    }

    @Test
    void keepsBucketsSeparatedByClientAddress() throws Exception {
        RateLimitFilter filter = filterWithAuthLimit(1);

        MockHttpServletResponse firstClient = invoke(filter, "POST", "/auth/login", "203.0.113.10");
        MockHttpServletResponse secondClient = invoke(filter, "POST", "/auth/login", "203.0.113.11");

        assertThat(firstClient.getStatus()).isEqualTo(200);
        assertThat(secondClient.getStatus()).isEqualTo(200);
    }

    @Test
    void doesNotRateLimitOptionsRequests() throws Exception {
        RateLimitFilter filter = filterWithAuthLimit(1);

        MockHttpServletResponse first = invoke(filter, "OPTIONS", "/auth/login");
        MockHttpServletResponse second = invoke(filter, "OPTIONS", "/auth/login");

        assertThat(first.getStatus()).isEqualTo(200);
        assertThat(second.getStatus()).isEqualTo(200);
    }

    private RateLimitFilter filterWithAuthLimit(int requests) {
        return new RateLimitFilter(
                true,
                new RateLimitFilter.Limit(requests, 60),
                new RateLimitFilter.Limit(30, 60),
                new RateLimitFilter.Limit(40, 60),
                new RateLimitFilter.Limit(240, 60),
                clock
        );
    }

    private MockHttpServletResponse invoke(
            RateLimitFilter filter,
            String method,
            String path
    ) throws Exception {
        return invoke(filter, method, path, "203.0.113.10");
    }

    private MockHttpServletResponse invoke(
            RateLimitFilter filter,
            String method,
            String path,
            String remoteAddress
    ) throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest(method, path);
        request.setRemoteAddr(remoteAddress);
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilter(request, response, new MockFilterChain());
        return response;
    }
}
