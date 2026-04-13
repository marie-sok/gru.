import 'package:flutter/material.dart';
import 'chat_socket.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {

  final socket = ChatSocket();
  final controller = TextEditingController();

  List<String> messages = [];

  @override
  void initState() {
    super.initState();

    socket.connect("JWT_TOKEN_HERE");

    socket.stream.listen((event) {
      setState(() {
        messages.add(event.toString());
      });
    });
  }

  void send() {
    socket.sendMessage("chat1", "1", "2", controller.text);
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [

          Expanded(
            child: ListView(
              children: messages
                  .map((m) => Text(m, style: const TextStyle(color: Colors.white)))
                  .toList(),
            ),
          ),

          Row(
            children: [
              Expanded(
                child: TextField(controller: controller),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: send,
              )
            ],
          )
        ],
      ),
    );
  }
}