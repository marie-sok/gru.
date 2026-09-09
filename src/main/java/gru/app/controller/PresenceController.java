package gru.app.controller;

import gru.app.model.Chat;
import gru.app.model.User;
import gru.app.repository.ChatRepository;
import gru.app.repository.UserRepository;
import gru.app.service.PresenceRegistry;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

@RestController
@RequestMapping("/presence")
@RequiredArgsConstructor
public class PresenceController {

    private final PresenceRegistry presenceRegistry;
    private final ChatRepository chatRepository;
    private final UserRepository userRepository;

    @GetMapping
    public Set<String> onlineUsers(Authentication authentication) {
        String requesterId = requireAuthenticatedUser(authentication);
        User requester = userRepository.findById(requesterId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Unauthorized"));

        Set<String> candidatePeerIds = new HashSet<>();
        List<Chat> chats = chatRepository.findByParticipantsContains(requesterId);
        if (chats != null) {
            for (Chat chat : chats) {
                if (chat.getParticipants() == null) continue;
                for (String participantId : chat.getParticipants()) {
                    if (participantId != null
                            && !participantId.isBlank()
                            && !participantId.equals(requesterId)) {
                        candidatePeerIds.add(participantId);
                    }
                }
            }
        }

        Set<String> visibleIds = new HashSet<>();
        // Keeping self in the snapshot lets the client represent its own online
        // state without learning anything about unrelated accounts.
        visibleIds.add(requesterId);

        if (!candidatePeerIds.isEmpty()) {
            for (User peer : userRepository.findAllById(candidatePeerIds)) {
                if (peer == null || peer.getId() == null) continue;
                if (!isPresenceVisibleBetween(requester, peer)) continue;
                visibleIds.add(peer.getId());
            }
        }

        Set<String> online = presenceRegistry.snapshot();
        Set<String> result = new HashSet<>();
        for (String userId : online) {
            if (visibleIds.contains(userId)) {
                result.add(userId);
            }
        }
        return Set.copyOf(result);
    }

    private String requireAuthenticatedUser(Authentication authentication) {
        if (authentication == null
                || !authentication.isAuthenticated()
                || authentication.getName() == null
                || authentication.getName().isBlank()) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Unauthorized");
        }
        return authentication.getName();
    }

    private boolean isPresenceVisibleBetween(User first, User second) {
        return !isBlocked(first, second.getId()) && !isBlocked(second, first.getId());
    }

    private boolean isBlocked(User user, String targetUserId) {
        return user.getBlockedUserIds() != null
                && user.getBlockedUserIds().contains(targetUserId);
    }
}
