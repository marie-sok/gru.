package gru.app.controller;

import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
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
import java.util.Locale;
import java.util.Map;

@RestController
@RequestMapping("/bot")
public class GRUBotController {

    private final RestClient restClient;

    public GRUBotController() {
        SimpleClientHttpRequestFactory requestFactory = new SimpleClientHttpRequestFactory();
        requestFactory.setConnectTimeout(4_000);
        requestFactory.setReadTimeout(8_000);
        this.restClient = RestClient.builder()
                .requestFactory(requestFactory)
                .build();
    }

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
            System.err.println("gru.bot: OPENAI_API_KEY is missing; local fallback enabled");
            return localFallback(request, "local");
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
                System.err.println("gru.bot: AI returned empty response; local fallback enabled");
                return localFallback(request, "empty-provider-response");
            }

            return new BotResponse(reply.trim(), model);

        } catch (RestClientResponseException error) {
            System.err.println(
                    "gru.bot OpenAI HTTP " + error.getStatusCode() + ": " + error.getResponseBodyAsString()
            );
            return localFallback(request, "provider-http-error");
        } catch (Exception error) {
            System.err.println("gru.bot provider timeout/error: " + error.getMessage());
            return localFallback(request, "provider-timeout-or-error");
        }
    }

    private BotResponse localFallback(BotRequest request, String reason) {
        String text = request.text().trim();
        String lower = text.toLowerCase(Locale.ROOT);
        boolean russian = text.matches(".*[А-Яа-яЁё].*");
        boolean asksForPlan =
                lower.contains("план") ||
                lower.contains("сплан") ||
                lower.contains("по шаг") ||
                lower.contains("plan") ||
                lower.contains("steps") ||
                lower.contains("schedule");

        if (asksForPlan) {
            String reply = russian
                    ? "Соберу рабочий план по запросу «" + text + "».\n\n" +
                      "1. Сформулируй конечный результат одним предложением.\n" +
                      "2. Отдели обязательное от желательного и зафиксируй ограничения.\n" +
                      "3. Разбей работу на 3–5 коротких этапов с понятным результатом каждого.\n" +
                      "4. Начни с шага, который снимает самый большой риск или зависимость.\n" +
                      "5. После первого результата пересобери следующие шаги по фактам.\n\n" +
                      "Следующий конкретный шаг: напиши мне срок и что уже готово — я соберу более точный план."
                    : "Here is a practical plan for “" + text + "”.\n\n" +
                      "1. Define the end result in one sentence.\n" +
                      "2. Separate must-haves from nice-to-haves and list constraints.\n" +
                      "3. Split the work into 3–5 short stages with a clear output for each.\n" +
                      "4. Start with the step that removes the biggest risk or dependency.\n" +
                      "5. Re-plan after the first concrete result.\n\n" +
                      "Next step: tell me your deadline and what is already done, and I’ll make it more specific.";
            return new BotResponse(reply, "gru-local-planner");
        }

        if (lower.contains("привет") || lower.contains("hello") || lower.contains("hi ") || lower.equals("hi")) {
            return new BotResponse(
                    russian
                            ? "Привет. Я на связи. Можем поболтать, разобрать мысль или собрать план — кидай тему как есть."
                            : "Hey. I’m here. We can chat, think something through, or build a plan — send it as it is.",
                    "gru-local-chat"
            );
        }

        String reply = russian
                ? "Я понял запрос: «" + text + "». AI-канал сейчас работает в резервном режиме, но я не буду молчать. " +
                  "Могу продолжить разговор, помочь разложить задачу, сравнить варианты или собрать план. " +
                  "Если хочешь конкретный разбор, добавь цель и главный вопрос."
                : "I got it: “" + text + "”. The AI provider is currently in fallback mode, but I won’t leave the request unanswered. " +
                  "I can still help structure the problem, compare options, or build a plan. Add the goal and the main question for a more concrete answer.";

        System.err.println("gru.bot local fallback reason=" + reason);
        return new BotResponse(reply, "gru-local-chat");
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
