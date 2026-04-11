package gru.app.websocket;

import lombok.RequiredArgsConstructor;
import lombok.Setter;
import org.springframework.context.annotation.Configuration;

@Setter
@Configuration
@RequiredArgsConstructor
public class WebSocketSecurityConfig implements WebSocketMessageBrokerConfigurer {

    private JwtChannelInterceptor interceptor;

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {

    }

    @Override
    public void configureMessageBroker(MessageBrokerRegistry registry) {

    }

    @Override
    public void configureClientInboundChannel(ChannelRegistration registration) {
        registration.interceptors(interceptor);
    }

}