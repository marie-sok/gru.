package gru.app.websocket;

public interface WebSocketMessageBrokerConfigurer {
    void registerStompEndpoints(StompEndpointRegistry registry);

    void configureMessageBroker(MessageBrokerRegistry registry);

    void configureClientInboundChannel(ChannelRegistration registration);
}
