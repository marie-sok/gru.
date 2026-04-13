import 'package:flutter/material.dart';

import 'chat_service.dart';

class ChatScreen extends StatefulWidget {
  @override
  State createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final service = ChatService();
  final controller = TextEditingController();
  List messages = [];

  @override
  void initState() {
    super.initState();

    service.messages.listen((msg) {
      setState(() {
        messages.add(msg);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 🔥 твой стиль
      appBar: AppBar(title: Text("gru.")),

      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (_, i) => Text(
                messages[i].toString(),
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: TextStyle(color: Colors.white),
                ),
              ),
              IconButton(
                icon: Icon(Icons.send),
                onPressed: () {
                  service.sendMessage("1", "2", controller.text);
                  controller.clear();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
