package gru.app.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 5)
public class EdgeProxyEnforcementFilter extends OncePerRequestFilter {

    private static final String SECRET_HEADER = "X-GRU-Edge-Secret";
    private static final String CLIENT_IP_HEADER = "X-GRU-Client-IP";

    private final boolean required;
    private final String sharedSecret;

    public EdgeProxyEnforcementFilter(
            @Value("${gru.security.edge.required:false}") boolean required,
            @Value("${gru.security.edge.shared-secret:}") String sharedSecret
    ) {
        this.required = required;
        this.sharedSecret = sharedSecret == null ? "" : sharedSecret.trim();

        if (required && this.sharedSecret.length() < 32) {
            throw new IllegalStateException(
                    "GRU edge is required but GRU_EDGE_SHARED_SECRET is missing or too short"
            );
        }
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        if (!required) {
            // Until DNS/proxy cutover, never trust caller-supplied edge headers.
            filterChain.doFilter(request, response);
            return;
        }

        String suppliedSecret = request.getHeader(SECRET_HEADER);
        if (!constantTimeEquals(sharedSecret, suppliedSecret)) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            response.setContentType("application/json");
            response.setCharacterEncoding("UTF-8");
            response.setHeader("Cache-Control", "no-store");
            response.getWriter().write("{\"error\":\"edge_required\"}");
            return;
        }

        String trustedClientIP = normalizeIP(request.getHeader(CLIENT_IP_HEADER));
        HttpServletRequest effectiveRequest = request;
        if (trustedClientIP != null) {
            effectiveRequest = new TrustedRemoteAddressRequest(request, trustedClientIP);
        }

        filterChain.doFilter(effectiveRequest, response);
    }

    private boolean constantTimeEquals(String expected, String supplied) {
        if (supplied == null) return false;
        return MessageDigest.isEqual(
                expected.getBytes(StandardCharsets.UTF_8),
                supplied.trim().getBytes(StandardCharsets.UTF_8)
        );
    }

    private String normalizeIP(String raw) {
        if (raw == null) return null;
        String value = raw.trim();
        if (value.startsWith("::ffff:")) value = value.substring(7);
        if (value.isEmpty() || value.length() > 64) return null;

        // Edge already validates with Node net.isIP. Keep backend parsing strict
        // and side-effect free rather than doing DNS resolution here.
        if (!value.matches("[0-9A-Fa-f:.]+")) return null;
        return value;
    }

    private static final class TrustedRemoteAddressRequest extends HttpServletRequestWrapper {
        private final String remoteAddress;

        private TrustedRemoteAddressRequest(HttpServletRequest request, String remoteAddress) {
            super(request);
            this.remoteAddress = remoteAddress;
        }

        @Override
        public String getRemoteAddr() {
            return remoteAddress;
        }
    }
}
