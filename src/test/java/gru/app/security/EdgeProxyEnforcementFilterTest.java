package gru.app.security;

import jakarta.servlet.ServletRequest;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;

class EdgeProxyEnforcementFilterTest {

    private static final String SECRET = "0123456789abcdef0123456789abcdef";

    @Test
    void rejectsDirectRequestWhenEdgeIsRequired() throws Exception {
        EdgeProxyEnforcementFilter filter = new EdgeProxyEnforcementFilter(true, SECRET);
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/health");
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilter(request, response, new MockFilterChain());

        assertThat(response.getStatus()).isEqualTo(403);
        assertThat(response.getContentAsString()).contains("edge_required");
    }

    @Test
    void acceptsCorrectSecretAndUsesEdgeValidatedClientAddress() throws Exception {
        EdgeProxyEnforcementFilter filter = new EdgeProxyEnforcementFilter(true, SECRET);
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/health");
        request.setRemoteAddr("10.0.0.12");
        request.addHeader("X-GRU-Edge-Secret", SECRET);
        request.addHeader("X-GRU-Client-IP", "203.0.113.77");
        MockHttpServletResponse response = new MockHttpServletResponse();
        AtomicReference<String> seenRemote = new AtomicReference<>();

        MockFilterChain chain = new MockFilterChain((servletRequest, servletResponse) -> {
            seenRemote.set(servletRequest.getRemoteAddr());
        });

        filter.doFilter(request, response, chain);

        assertThat(response.getStatus()).isEqualTo(200);
        assertThat(seenRemote.get()).isEqualTo("203.0.113.77");
    }

    @Test
    void ignoresSpoofedEdgeHeadersBeforeCutover() throws Exception {
        EdgeProxyEnforcementFilter filter = new EdgeProxyEnforcementFilter(false, "");
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/health");
        request.setRemoteAddr("198.51.100.10");
        request.addHeader("X-GRU-Client-IP", "203.0.113.99");
        MockHttpServletResponse response = new MockHttpServletResponse();
        AtomicReference<String> seenRemote = new AtomicReference<>();

        MockFilterChain chain = new MockFilterChain((servletRequest, servletResponse) -> {
            seenRemote.set(servletRequest.getRemoteAddr());
        });

        filter.doFilter(request, response, chain);

        assertThat(seenRemote.get()).isEqualTo("198.51.100.10");
    }
}
