import 'dart:convert';

class ChatSocket {
  get channel => channel;

  void connect(String token) {
    SetChannel = WebSocketChannel.connect(
      Uri.parse("ws://localhost:8081/ws?token=$token"),
    );
  }

  void sendMessage(
    String chatId,
    String senderId,
    String receiverId,
    String text,
  ) {
    channel.sink.add(
      jsonEncode({
        "type": "MESSAGE",
        "chatId": chatId,
        "senderId": senderId,
        "receiverId": receiverId,
        "content": text,
      }),
    );
  }

  Stream get stream => channel.stream;

  get WebSocketChannel => null;

  set SetChannel(SetChannel) {}
}

class WebSocketChannel {}
