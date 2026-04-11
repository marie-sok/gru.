package gru.app.security;

import gru.app.model.Message;

public interface JwtChannelInterceptor {
    Message<?> getMessageChannel(Message<?> message, Object o);
}
