package ai.limitless.arkgum.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Gate for {@code /api/**}: requires a shared secret in the {@code X-Sync-Token} header that
 * matches {@code sync.token} from configuration. Comparison is constant-time.
 *
 * <p>This is a single-user personal deployment guard, not a full auth system. For anything
 * multi-user, replace with Spring Security + per-user credentials.
 */
@Component
public class SyncTokenFilter extends OncePerRequestFilter {

    private final String expectedToken;

    public SyncTokenFilter(@Value("${sync.token:}") String expectedToken) {
        this.expectedToken = expectedToken;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !request.getRequestURI().startsWith("/api/");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        if (expectedToken == null || expectedToken.isBlank()) {
            response.sendError(HttpServletResponse.SC_SERVICE_UNAVAILABLE,
                    "sync.token is not configured on the server");
            return;
        }
        String provided = request.getHeader("X-Sync-Token");
        if (provided == null || !constantTimeEquals(provided, expectedToken)) {
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Invalid sync token");
            return;
        }
        chain.doFilter(request, response);
    }

    private static boolean constantTimeEquals(String a, String b) {
        return MessageDigest.isEqual(
                a.getBytes(StandardCharsets.UTF_8),
                b.getBytes(StandardCharsets.UTF_8));
    }
}
