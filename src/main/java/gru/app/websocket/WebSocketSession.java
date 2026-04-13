package gru.app.websocket;

import java.net.URI;
import java.security.Principal;

public class WebSocketSession {
    public String getId() {
        return "";
    }

    public boolean isOpen() {
        return false;
    }

    public void sendMessage(TextMessage message) {

    }

    public URI getUri() {
        return null;
    }

    public void close(Object notAcceptable) {
    }

    public Principal getPrincipal() {
        return null;
    }
}
