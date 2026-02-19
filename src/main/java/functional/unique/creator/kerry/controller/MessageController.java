package functional.unique.creator.kerry.controller;

import functional.unique.creator.kerry.model.Message;
import functional.unique.creator.kerry.service.MessageService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/messages")
@RequiredArgsConstructor
public class MessageController {

    private final MessageService service;

    @PostMapping("/send")
    public Message send(@RequestParam String sender,
                        @RequestParam String receiver,
                        @RequestParam String content) {
        return service.sendMessage(sender, receiver, content);
    }

    @GetMapping("/history")
    public List<Message> history(@RequestParam String sender,
                                 @RequestParam String receiver) {
        return service.getHistory(sender, receiver);
    }
}
