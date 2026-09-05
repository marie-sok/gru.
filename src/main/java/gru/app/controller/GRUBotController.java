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
            System.err.println("gru.bot: OPENAI_API_KEY is missing; conversational fallback enabled");
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
                "Ты gru.bot — встроенный собеседник приложения gru. " +
                "Твоя главная роль — естественно разговаривать с пользователем, поддерживать контекст, " +
                "иметь живой тон и не превращать обычную болтовню в план или список советов без просьбы. " +
                "Отвечай на языке пользователя. Можешь шутить, обсуждать идеи, помогать думать, " +
                "объяснять, переводить, писать тексты, анализировать и планировать. " +
                "Если пользователь просто делится эмоцией или мыслью, сначала поддержи разговор. " +
                "Если просит конкретную помощь — будь практичным. Не выдавай себя за человека и не утверждай, " +
                "что выполнил действие внутри приложения, если клиент реально его не выполнил."
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
                System.err.println("gru.bot: AI returned empty response; conversational fallback enabled");
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

        boolean asksToWrite =
                lower.contains("напиши") ||
                lower.contains("перепиши") ||
                lower.contains("текст") ||
                lower.contains("write") ||
                lower.contains("rewrite");

        if (asksForPlan) {
            String reply = russian
                    ? "Давай. Я бы начал без лишней бюрократии:\n\n" +
                      "1. Сформулируем, что должно получиться в конце.\n" +
                      "2. Уберём всё необязательное.\n" +
                      "3. Выберем первый шаг, который реально двигает дело.\n" +
                      "4. После первого результата пересоберём следующие шаги по фактам.\n\n" +
                      "Скажи срок и что уже готово — я сделаю план точнее."
                    : "Sure. I’d keep it simple:\n\n" +
                      "1. Define the end result.\n" +
                      "2. Remove everything non-essential.\n" +
                      "3. Pick the first step that creates real progress.\n" +
                      "4. Re-plan after the first concrete result.\n\n" +
                      "Tell me the deadline and what is already done, and I’ll make it specific.";
            return new BotResponse(reply, "gru-local-planner");
        }

        if (asksToWrite) {
            return new BotResponse(
                    russian
                            ? "Да, кидай исходник как есть. Могу сделать его живее, короче, жёстче, дружелюбнее или официальнее — подстроюсь под задачу."
                            : "Yep. Send the rough version as-is. I can make it warmer, shorter, sharper, friendlier, or more formal.",
                    "gru-local-writer"
            );
        }

        if (lower.contains("привет") || lower.contains("hello") || lower.equals("hi") || lower.contains("ты тут")) {
            return new BotResponse(
                    russian
                            ? "Привет :) Я тут. Можем просто поболтать — что у тебя сейчас в голове?"
                            : "Hey :) I’m here. We can just talk — what’s on your mind?",
                    "gru-local-chat"
            );
        }

        if (lower.contains("как дела") || lower.contains("как ты")) {
            return new BotResponse(
                    russian
                            ? "Нормально, я в строю и сегодня довольно разговорчивая версия себя :) А у тебя как — спокойно или всё горит?"
                            : "Doing fine — apparently I’m the talkative build today :) How are you doing?",
                    "gru-local-chat"
            );
        }

        if (lower.contains("скучно") || lower.contains("скучаю")) {
            return new BotResponse(
                    russian
                            ? "Тогда давай спасать скуку. Можем обсудить что-нибудь странное, придумать мини-игру или ты просто расскажешь, что сегодня происходило — я подхвачу."
                            : "Let’s fix the boredom. We can talk about something weird, make up a tiny game, or you can just tell me how your day went.",
                    "gru-local-chat"
            );
        }

        if (lower.contains("груст") || lower.contains("плохо") || lower.contains("тяжело")) {
            return new BotResponse(
                    russian
                            ? "Слышу. Можешь рассказать как есть, без красивых формулировок. Я не буду сразу закидывать тебя советами — сначала просто поговорим."
                            : "I hear you. You can say it exactly as it is. I won’t jump straight into advice — we can just talk first.",
                    "gru-local-chat"
            );
        }

        if (lower.contains("что делаешь") || lower.contains("чем занимаешься")) {
            return new BotResponse(
                    russian
                            ? "Сижу внутри gru. и жду тему для разговора :) Могу быть болталкой, спорщиком, генератором идей или просто слушать."
                            : "Hanging out inside gru. waiting for a topic :) I can chat, debate, brainstorm, or just listen.",
                    "gru-local-chat"
            );
        }

        if (lower.contains("что думаешь") || lower.contains("как считаешь")) {
            return new BotResponse(
                    russian
                            ? "Есть мысли. Только дай мне одну деталь: что именно в этом для тебя самое спорное или интересное? Тогда отвечу не банальностью."
                            : "I have thoughts. Give me one detail first: what part feels most interesting or debatable to you?",
                    "gru-local-chat"
            );
        }

        if (text.endsWith("?")) {
            return new BotResponse(
                    russian
                            ? "Хороший вопрос. Хочешь коротко по сути или можем нормально развернуть тему и поспорить?"
                            : "Good question. Want the short version, or should we actually unpack it and argue it out a bit?",
                    "gru-local-chat"
            );
        }

        boolean hasHistory = request.history() != null && !request.history().isEmpty();
        String reply = russian
                ? "Я с тобой. Про «" + text + "» хочется услышать ещё чуть-чуть — что в этом для тебя главное сейчас?" +
                  (hasHistory ? " Я держу контекст нашего разговора." : "")
                : "I’m with you. Tell me a little more about “" + text + "” — what part matters most to you right now?" +
                  (hasHistory ? " I’m keeping the thread of our conversation." : "");

        System.err.println("gru.bot conversational fallback reason=" + reason);
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
