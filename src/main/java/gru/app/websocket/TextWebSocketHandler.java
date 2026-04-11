package gru.app.websocket;

public abstract class TextWebSocketHandler {
    public abstract void afterConnectionEstablished(WebSocketSession session);

    protected abstract void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception;

    public abstract void afterConnectionClosed(WebSocketSession session, CloseStatus status);
}
