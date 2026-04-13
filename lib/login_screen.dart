import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phoneController = TextEditingController();
  final codeController = TextEditingController();

  bool codeSent = false;

  Future<void> sendCode() async {
    await http.post(
      Uri.parse("http://localhost:8081/auth/send"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"phone": phoneController.text}),
    );

    setState(() => codeSent = true);
  }

  Future<void> verify() async {
    final res = await http.post(
      Uri.parse("http://localhost:8081/auth/verify"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "phone": phoneController.text,
        "code": codeController.text,
      }),
    );

    final data = jsonDecode(res.body);
    final token = data["token"];

    print("JWT TOKEN: $token");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "gru.",
              style: TextStyle(color: Colors.white, fontSize: 40),
            ),

            TextField(
              controller: phoneController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Phone",
                hintStyle: TextStyle(color: Colors.grey),
              ),
            ),

            if (codeSent)
              TextField(
                controller: codeController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Code",
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: codeSent ? verify : sendCode,
              child: Text(codeSent ? "Verify" : "Send Code"),
            ),
          ],
        ),
      ),
    );
  }
}
