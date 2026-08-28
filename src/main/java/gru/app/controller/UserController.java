package gru.app.controller;

import gru.app.dto.ReportUserRequest;
import gru.app.dto.UserSafetyResponse;
import gru.app.dto.UserSearchResponse;
import gru.app.model.AbuseReport;
import gru.app.model.Chat;
import gru.app.model.Message;
import gru.app.model.User;
import gru.app.repository.AbuseReportRepository;
import gru.app.repository.ChatRepository;
import gru.app.repository.MessageRepository;
import gru.app.repository.UserRepository;
import gru.app.service.MediaStorageService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@RestController
@RequestMapping("/users")
@RequiredArgsConstructor
public class UserController {

    private final UserRepository userRepository;
    private final ChatRepository chatRepository;
    private final MessageRepository messageRepository;
    private final AbuseReportRepository abuseReportRepository;
    private final MediaStorageService mediaStorageService;

    @GetMapping("/search")
    public List<UserSearchResponse> search(
            Authentication authentication,
            @RequestParam String nickname
    ) {
        String currentUserId = authentication.getName();
        String query = nickname == null ? "" : nickname.trim();
        if (query.length() < 2) return List.of();

        User currentUser = requireUser(currentUserId);
        Set<String> blocked = safeBlocked(currentUser);

        return userRepository
                .findByNicknameContainingIgnoreCase(query)
                .stream()
                .filter(user -> !user.getId().equals(currentUserId))
                .filter(user -> !blocked.contains(user.getId()))
                .filter(user -> !safeBlocked(user).contains(currentUserId))
                .limit(20)
                .map(this::toResponse)
                .toList();
    }

    @GetMapping("/{targetUserId}/safety")
    public UserSafetyResponse safety(
            Authentication authentication,
            @PathVariable String targetUserId
    ) {
        User current = requireUser(authentication.getName());
        return new UserSafetyResponse(safeBlocked(current).contains(targetUserId));
    }

    @PostMapping("/{targetUserId}/block")
    public UserSafetyResponse block(
            Authentication authentication,
            @PathVariable String targetUserId
    ) {
        String currentUserId = authentication.getName();
        if (currentUserId.equals(targetUserId)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Cannot block yourself");
        }
        requireUser(targetUserId);
        User current = requireUser(currentUserId);
        Set<String> blocked = safeBlocked(current);
        blocked.add(targetUserId);
        current.setBlockedUserIds(blocked);
        userRepository.save(current);
        return new UserSafetyResponse(true);
    }

    @DeleteMapping("/{targetUserId}/block")
    public UserSafetyResponse unblock(
            Authentication authentication,
            @PathVariable String targetUserId
    ) {
        User current = requireUser(authentication.getName());
        Set<String> blocked = safeBlocked(current);
        blocked.remove(targetUserId);
        current.setBlockedUserIds(blocked);
        userRepository.save(current);
        return new UserSafetyResponse(false);
    }

    @PostMapping("/{targetUserId}/report")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public void report(
            Authentication authentication,
            @PathVariable String targetUserId,
            @RequestBody ReportUserRequest request
    ) {
        String reporterId = authentication.getName();
        if (reporterId.equals(targetUserId)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Cannot report yourself");
        }
        requireUser(targetUserId);
        String reason = request == null || request.reason() == null ? "other" : request.reason().trim();
        if (reason.isBlank()) reason = "other";

        AbuseReport report = new AbuseReport();
        report.setReporterId(reporterId);
        report.setTargetUserId(targetUserId);
        report.setChatId(request == null ? null : clean(request.chatId(), 120));
        report.setReason(clean(reason, 80));
        report.setDetails(request == null ? null : clean(request.details(), 1000));
        report.setStatus("open");
        report.setCreatedAt(Instant.now());
        abuseReportRepository.save(report);
    }

    @DeleteMapping("/me")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteMyAccount(Authentication authentication) {
        String userId = authentication.getName();
        requireUser(userId);

        List<Chat> chats = chatRepository.findByParticipantsContains(userId);
        for (Chat chat : chats) {
            List<Message> messages = messageRepository.findByChatIdOrderByCreatedAtAsc(chat.getId());
            for (Message message : messages) {
                if (message.getAttachment() != null) {
                    mediaStorageService.deleteByRemoteURL(message.getAttachment().getRemoteURL());
                }
            }
            messageRepository.deleteAll(messages);
            chatRepository.delete(chat);
        }

        abuseReportRepository.deleteByReporterId(userId);
        abuseReportRepository.deleteByTargetUserId(userId);

        for (User user : userRepository.findAll()) {
            Set<String> blocked = safeBlocked(user);
            if (blocked.remove(userId)) {
                user.setBlockedUserIds(blocked);
                userRepository.save(user);
            }
        }

        userRepository.deleteById(userId);
    }

    private User requireUser(String userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));
    }

    private Set<String> safeBlocked(User user) {
        return user.getBlockedUserIds() == null
                ? new HashSet<>()
                : new HashSet<>(user.getBlockedUserIds());
    }

    private String clean(String value, int max) {
        if (value == null) return null;
        String result = value.trim();
        if (result.isEmpty()) return null;
        return result.length() <= max ? result : result.substring(0, max);
    }

    private UserSearchResponse toResponse(User user) {
        return new UserSearchResponse(user.getId(), user.getNickname());
    }
}
