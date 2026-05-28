package gru.app.controller;

import gru.app.dto.EditMessageRequest;
import gru.app.dto.MessageResponse;
import gru.app.service.MessageService;

import lombok.RequiredArgsConstructor;

import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/messages")
@RequiredArgsConstructor
public class MessageController {

    private final MessageService messageService;

    @PutMapping("/{id}")
    public MessageResponse edit(
            @PathVariable String id,
            @RequestBody EditMessageRequest request
    ) {

        return messageService.editMessage(
                id,
                request.getContent()
        );
    }

    @DeleteMapping("/{id}")
    public void delete(
            @PathVariable String id
    ) {

        messageService.deleteMessage(id);
    }
}