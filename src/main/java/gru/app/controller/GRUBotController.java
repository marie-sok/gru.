package gru.app.controller;

import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;
import org.springframework.web.server.ResponseStatusException;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/bot")
public class GRUBotController {

    private final RestClient restClient = RestClient.create();

    public record BotTurn(String role, String text) {}
    public record BotRequest(String text, List<BotTurn> history) {}
    public record BotResponse(String reply, String model) {}

    @PostMapping("/chat")
    public BotResponse chat(
            Authentication authentication,
            @RequestBody BotRequest request
    ) {
        if (authentication == null || !authentication.isAuthenticated()) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Authentication required");
        }

        if (request == null || request.text() == null || request.text().trim().isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Text is required");
        }

        String apiKey = System.getenv("OPENAI_API_KEY");
        if (apiKey == null || apiKey.isBlank()) {
            throw new ResponseStatusException(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "OPENAI_API_KEY is not configured"
            );
        }

        String model = env("GRU_BOT_MODEL", "gpt-5.6-luna");
        String endpoint = "https://api.openai.com/v1/responses";

        StringBuilder transcript = new StringBuilder();
        if (request.history() != null) {
            int start = Math.max(0, request.history().size() - 30);
            for (int i = start; i < request.history().size(); i++) {
                BotTurn turn = request.history().get(i);
                if (turn == null || turn.text() == null || turn.text().isBlank()) {
                    continue;
                }

                String role = "assistant".equalsIgnoreCase(turn.role()) ? "gru.bot" : "user";
                transcript.append(role)
                        .append(": ")
                        .append(turn.text().trim())
                        .append("\n");
            }
        }

        transcript.append("user: ")
                .append(request.text().trim())
                .append("\ngru.bot:");

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("model", model);
        payload.put(
                "instructions",
                "Ты gru.bot — встроенный AI-собеседник приложения gru. " +
                "Веди естественный последовательный диалог и учитывай историю. " +
                "Отвечай на языке пользователя. Умей просто болтать, помогать думать, " +
                "объяснять, переводить, писать тексты, анализировать и планировать. " +
                "Когда пользователь просит план, раскладывай цель на понятные шаги, " +
                "приоритеты, зависимости и следующий конкретный шаг. " +
                "Не выдавай себя за человека и не утверждай, что выполнил действие, " +
                "которое реально не выполнялось."
        );
        payload.put("input", transcript.toString());

        try {
            @SuppressWarnings("unchecked")
            Map<String, Object> response = restClient
                    .post()
                    .uri(endpoint)
                    .header(HttpHeaders.AUTHORIZATION, "Bearer " + apiKey)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(payload)
                    .retrieve()
                    .body(Map.class);

            String reply = extractOutputText(response);
            if (reply == null || reply.isBlank()) {
                throw new ResponseStatusException(
                        HttpStatus.BAD_GATEWAY,
                        "AI returned empty response"
                );
            }

            return new BotResponse(reply.trim(), model);

        } catch (RestClientResponseException error) {
            System.err.println(
                    "gru.bot OpenAI HTTP " + error.getStatusCode() + ": " + error.getResponseBodyAsString()
            );
            throw new ResponseStatusException(
                    HttpStatus.BAD_GATEWAY,
                    "AI provider returned an error"
            );
        } catch (ResponseStatusException error) {
            throw error;
        } catch (Exception error) {
            error.printStackTrace();
            throw new ResponseStatusException(
                    HttpStatus.BAD_GATEWAY,
                    "gru.bot is temporarily unavailable"
            );
        }
    }

    private String extractOutputText(Map<String, Object> response) {
        if (response == null) return null;

        Object outputObject = response.get("output");
        if (!(outputObject instanceof List<?> output)) return null;

        for (Object itemObject : output) {
            if (!(itemObject instanceof Map<?, ?> item)) continue;
            Object contentObject = item.get("content");
            if (!(contentObject instanceof List<?> content)) continue;

            for (Object partObject : content) {
                if (!(partObject instanceof Map<?, ?> part)) continue;
                if (!"output_text".equals(String.valueOf(part.get("type")))) continue;

                Object text = part.get("text");
                if (text != null && !String.valueOf(text).isBlank()) {
                    return String.valueOf(text);
                }
            }
        }

        return null;
    }

    private String env(String name, String fallback) {
        String value = System.getenv(name);
        return value == null || value.isBlank() ? fallback : value;
    }
}
