package gru.app.service;

import gru.app.model.Chat;
import gru.app.repository.ChatRepository;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import lombok.Setter;
import org.springframework.stereotype.Service;

import java.util.List;

@Getter
@Setter
@Service
@RequiredArgsConstructor
public class ChatService {

    private final ChatRepository chatRepository;

    public Chat createPrivateChat(String user1, String user2) {
        return null;
    }

    public Chat createGroup(String creator, String title, List<String> users) {
        return null;
    }
}



