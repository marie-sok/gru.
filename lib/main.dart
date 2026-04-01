import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  String result = "";

  Future<void> login() async {
    try {
      final response = await http.post(
        Uri.parse("http://10.0.2.2:8081/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phone": phoneController.text,
          "password": passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          result = "JWT:\n${response.body}";
        });
      } else {
        setState(() {
          result = "Ошибка: ${response.statusCode}\n${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        result = "Ошибка подключения: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Login"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: "Phone"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: login,
              child: const Text("Login"),
            ),
            const SizedBox(height: 20),
            SelectableText(result),
          ],
        ),
      ),
    );
  }
}