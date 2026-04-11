package gru.app.websocket;

import gru.app.model.Message;

public interface StompHeaderAccessor {
    static StompHeaderAccessor wrap(Message<?> message) {
        return null;
    }

    String getCommand();

    String getFirstNativeHeader(String authorization);

    void setUser(Object o);
}
