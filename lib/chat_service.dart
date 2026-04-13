import 'dart:convert';

class ChatService {
  final channel = WebSocketChannel.connect(
    Uri.parse('ws://localhost:8080/chat'),
  );

  void sendMessage(String sender, String receiver, String content) {
    channel.sink.add(
      jsonEncode({
        "senderId": sender,
        "receiverId": receiver,
        "content": content,
      }),
    );
  }

  Stream get messages => channel.stream;

  static get WebSocketChannel => null;
}
