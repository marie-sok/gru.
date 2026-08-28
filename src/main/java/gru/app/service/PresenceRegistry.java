package gru.app.service;

import org.springframework.stereotype.Service;

import java.util.Collections;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class PresenceRegistry {

    private final ConcurrentHashMap<String, Set<String>> sessionsByUser = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, String> userBySession = new ConcurrentHashMap<>();

    public boolean connect(String userId, String sessionId) {
        if (userId == null || userId.isBlank() || sessionId == null || sessionId.isBlank()) {
            return false;
        }

        userBySession.put(sessionId, userId);

        Set<String> sessions = sessionsByUser.computeIfAbsent(
                userId,
                ignored -> ConcurrentHashMap.newKeySet()
        );

        boolean wasOffline = sessions.isEmpty();
        sessions.add(sessionId);
        return wasOffline;
    }

    public DisconnectResult disconnect(String sessionId) {
        if (sessionId == null || sessionId.isBlank()) {
            return DisconnectResult.none();
        }

        String userId = userBySession.remove(sessionId);
        if (userId == null) {
            return DisconnectResult.none();
        }

        Set<String> sessions = sessionsByUser.get(userId);
        if (sessions == null) {
            return new DisconnectResult(userId, true);
        }

        sessions.remove(sessionId);
        boolean becameOffline = sessions.isEmpty();

        if (becameOffline) {
            sessionsByUser.remove(userId, sessions);
        }

        return new DisconnectResult(userId, becameOffline);
    }

    public Set<String> snapshot() {
        return Collections.unmodifiableSet(Set.copyOf(sessionsByUser.keySet()));
    }

    public record DisconnectResult(String userId, boolean becameOffline) {
        public static DisconnectResult none() {
            return new DisconnectResult(null, false);
        }
    }
}
