package gru.app.controller;

import gru.app.dto.AiChatRequest;
import gru.app.dto.AiChatResponse;
import gru.app.service.GruAiService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/ai")
public class AiController {

    private final GruAiService gruAiService;

    public AiController(GruAiService gruAiService) {
        this.gruAiService = gruAiService;
    }

    @PostMapping("/chat")
    public AiChatResponse chat(@Valid @RequestBody AiChatRequest request) {
        String text = gruAiService.reply(request.message());
        return new AiChatResponse(text, gruAiService.model());
    }
}
