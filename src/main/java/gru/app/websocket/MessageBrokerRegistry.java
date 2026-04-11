package gru.app.websocket;

public interface MessageBrokerRegistry {
    void setApplicationDestinationPrefixes(String s);

    void enableSimpleBroker(String s, String s1);
}
