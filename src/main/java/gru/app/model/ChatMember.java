package gru.app.model;

import lombok.*;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ChatMember {

    private String userId;

    private ChatRole role;
}