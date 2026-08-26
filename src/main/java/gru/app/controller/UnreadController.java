package gru.app.controller;

import gru.app.dto.UnreadCountsResponse;
import gru.app.service.UnreadService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/messages")
@RequiredArgsConstructor
public class UnreadController {

    private final UnreadService unreadService;

    // MARK: - GET /messages/unread-counts

    @GetMapping("/unread-counts")
    public UnreadCountsResponse getUnreadCounts(
            Authentication authentication
    ) {

        if (
                authentication == null ||
                        !authentication.isAuthenticated()
        ) {

            throw new AccessDeniedException(
                    "Authentication required"
            );
        }

        String userId =
                authentication.getName();

        return unreadService
                .getUnreadCounts(
                        userId
                );
    }
}