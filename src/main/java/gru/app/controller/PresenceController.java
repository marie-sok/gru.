package gru.app.controller;

import gru.app.service.PresenceRegistry;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Set;

@RestController
@RequestMapping("/presence")
@RequiredArgsConstructor
public class PresenceController {

    private final PresenceRegistry presenceRegistry;

    @GetMapping
    public Set<String> onlineUsers() {
        return presenceRegistry.snapshot();
    }
}
