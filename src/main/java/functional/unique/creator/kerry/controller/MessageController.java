package functional.unique.creator.kerry.controller;

import functional.unique.creator.kerry.model.Message;
import functional.unique.creator.kerry.service.MessageService;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/messages")
@CrossOrigin
public class MessageController {

    private final MessageService service;

    public MessageController(MessageService service) {
        this.service = service;
    }

    public static class SendRequest {
        public Long receiverId;
        public String text;
    }


    @PostMapping("/send")
    public Message send(@RequestBody SendRequest req) {

        Long senderId = (Long) SecurityContextHolder
                .getContext()
                .getAuthentication()
                .getPrincipal();

        return service.send(senderId, req.receiverId, req.text);
    }


    @GetMapping("/history")
    public List<Message> history(@RequestParam Long otherUserId) {

        Long currentUser = (Long) SecurityContextHolder
                .getContext()
                .getAuthentication()
                .getPrincipal();

        return service.history(currentUser, otherUserId);
    }
}