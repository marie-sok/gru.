package gru.app.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Service
public class ContentSafetyService {

    private static final Pattern LINK_PATTERN = Pattern.compile("(?i)(https?://|www\\.)");

    private final List<String> blockedTerms;

    public ContentSafetyService(
            @Value("${gru.moderation.blocked-terms:}") String blockedTerms
    ) {
        this.blockedTerms = Arrays.stream(blockedTerms.split(","))
                .map(String::trim)
                .filter(value -> !value.isBlank())
                .map(value -> value.toLowerCase(Locale.ROOT))
                .distinct()
                .toList();
    }

    public void validateText(String text) {
        if (text == null || text.isBlank()) return;

        if (text.length() > 10_000) {
            throw new ResponseStatusException(
                    HttpStatus.UNPROCESSABLE_ENTITY,
                    "Message is too long"
            );
        }

        Matcher matcher = LINK_PATTERN.matcher(text);
        int links = 0;
        while (matcher.find()) {
            links++;
            if (links > 3) {
                throw new ResponseStatusException(
                        HttpStatus.UNPROCESSABLE_ENTITY,
                        "Message was rejected by anti-spam filter"
                );
            }
        }

        if (blockedTerms.isEmpty()) return;

        String normalized = text.toLowerCase(Locale.ROOT);
        for (String term : blockedTerms) {
            if (normalized.contains(term)) {
                throw new ResponseStatusException(
                        HttpStatus.UNPROCESSABLE_ENTITY,
                        "Message was rejected by content safety filter"
                );
            }
        }
    }
}
