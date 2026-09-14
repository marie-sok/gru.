import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const _magenta = Color(0xFFFF2BD6);
const _violet = Color(0xFF8B5CFF);
const _ink = Color(0xFF0B0715);
const _panel = Color(0xFF171126);

void main() {
  runApp(const GruApp());
}

class ApiException implements Exception {
  ApiException(this.message, this.statusCode);
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthResult {
  const AuthResult({required this.token, required this.userId});
  final String token;
  final String userId;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    final token = (json['token'] ?? json['accessToken'] ?? '').toString();
    final userId = (json['userId'] ?? json['id'] ?? '').toString();
    if (token.isEmpty || userId.isEmpty) {
      throw ApiException('Сервер вернул неполный ответ авторизации', 200);
    }
    return AuthResult(token: token, userId: userId);
  }
}

class ApiClient {
  ApiClient({String? baseUrl})
      : baseUrl = (baseUrl ??
                const String.fromEnvironment(
                  'GRU_API_BASE_URL',
                  defaultValue: 'https://gru-jiqi.onrender.com',
                ))
            .replaceFirst(RegExp(r'/$'), '');

  final String baseUrl;
  String? token;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request(method, _uri(path));
    request.headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final currentToken = token;
    if (currentToken != null && currentToken.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $currentToken';
    }

    final streamed = await request.send().timeout(const Duration(seconds: 20));
    final response = await http.Response.fromStream(streamed);
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = response.body;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? (decoded['message'] ?? decoded['error'] ?? 'HTTP ' + response.statusCode.toString())
              .toString()
          : 'HTTP ' + response.statusCode.toString();
      throw ApiException(message, response.statusCode);
    }
    return decoded;
  }

  Future<AuthResult> login(String phone, String password) async {
    final json = await _request(
      'POST',
      '/auth/login',
      body: {'phone': phone, 'password': password},
    );
    return AuthResult.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<AuthResult> register(
    String phone,
    String password,
    String nickname,
  ) async {
    final json = await _request(
      'POST',
      '/auth/register',
      body: {
        'phone': phone,
        'password': password,
        'nickname': nickname,
      },
    );
    return AuthResult.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<List<ChatSummary>> chats() async {
    final json = await _request('GET', '/chats');
    final list = json is List ? json : const <dynamic>[];
    return list
        .whereType<Map>()
        .map((item) => ChatSummary.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<ServerMessage>> messages(String chatId) async {
    final json = await _request('GET', '/chats/$chatId/messages');
    final list = json is List ? json : const <dynamic>[];
    return list
        .whereType<Map>()
        .map((item) => ServerMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}

class SecureSession {
  static const _storage = FlutterSecureStorage();

  Future<void> save(AuthResult result) => _storage.write(
        key: 'gru.auth',
        value: jsonEncode({
          'token': result.token,
          'userId': result.userId,
        }),
      );

  Future<AuthResult?> read() async {
    final value = await _storage.read(key: 'gru.auth');
    if (value == null || value.isEmpty) return null;
    try {
      final json = Map<String, dynamic>.from(jsonDecode(value) as Map);
      return AuthResult.fromJson(json);
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> clear() => _storage.delete(key: 'gru.auth');
}

class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.participants,
    this.createdAt,
  });

  final String id;
  final List<Participant> participants;
  final String? createdAt;

  factory ChatSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['participants'] is List
        ? json['participants'] as List
        : const <dynamic>[];
    return ChatSummary(
      id: (json['id'] ?? '').toString(),
      createdAt: json['createdAt']?.toString(),
      participants: raw
          .whereType<Map>()
          .map((item) => Participant.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  String titleFor(String currentUserId) {
    final other = participants.firstWhere(
      (participant) => participant.id != currentUserId,
      orElse: () => participants.isNotEmpty
          ? participants.first
          : const Participant(id: '', nickname: ''),
    );
    return other.nickname.isEmpty ? 'GRU chat' : other.nickname;
  }
}

class Participant {
  const Participant({required this.id, required this.nickname});
  final String id;
  final String nickname;

  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
        id: (json['id'] ?? '').toString(),
        nickname: (json['nickname'] ?? '').toString(),
      );
}

class ServerMessage {
  const ServerMessage({
    required this.id,
    required this.senderId,
    this.text,
    this.encryptedPayload,
    this.createdAt,
    this.deletedAt,
  });

  final String id;
  final String senderId;
  final String? text;
  final String? encryptedPayload;
  final String? createdAt;
  final String? deletedAt;

  factory ServerMessage.fromJson(Map<String, dynamic> json) => ServerMessage(
        id: (json['id'] ?? '').toString(),
        senderId: (json['senderId'] ?? '').toString(),
        text: json['text']?.toString(),
        encryptedPayload: json['encryptedPayload']?.toString(),
        createdAt: json['createdAt']?.toString(),
        deletedAt: json['deletedAt']?.toString(),
      );

  String get displayText {
    if (deletedAt != null) return 'Сообщение удалено';
    if (text != null && text!.trim().isNotEmpty) return text!;
    if (encryptedPayload != null && encryptedPayload!.isNotEmpty) {
      return '🔒 Зашифрованное сообщение';
    }
    return 'Сообщение без текста';
  }
}

class GruApp extends StatefulWidget {
  const GruApp({super.key});

  @override
  State<GruApp> createState() => _GruAppState();
}

class _GruAppState extends State<GruApp> {
  final _api = ApiClient();
  final _session = SecureSession();
  AuthResult? _auth;
  bool _checkingSession = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final saved = await _session.read();
    if (!mounted) return;
    if (saved != null) {
      _api.token = saved.token;
    }
    setState(() {
      _auth = saved;
      _checkingSession = false;
    });
  }

  Future<void> _signedIn(AuthResult result) async {
    _api.token = result.token;
    await _session.save(result);
    if (!mounted) return;
    setState(() => _auth = result);
  }

  Future<void> _signOut() async {
    await _session.clear();
    _api.token = null;
    if (!mounted) return;
    setState(() => _auth = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'gru.',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _ink,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _magenta,
          brightness: Brightness.dark,
          surface: _ink,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _ink,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _panel,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _magenta, width: 1.2),
          ),
          labelStyle: const TextStyle(color: Colors.white70),
        ),
      ),
      home: _checkingSession
          ? const _LoadingPage()
          : _auth == null
              ? AuthPage(api: _api, onAuthenticated: _signedIn)
              : HomePage(
                  api: _api,
                  currentUserId: _auth!.userId,
                  onLogout: _signOut,
                ),
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: _magenta),
      ),
    );
  }
}

class NeonScaffold extends StatelessWidget {
  const NeonScaffold({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_ink, Color(0xFF120B28), _ink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _Glow(color: _violet, size: 260),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: _Glow(color: _magenta, size: 280),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(.10),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(.45),
              blurRadius: 120,
              spreadRadius: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({
    required this.api,
    required this.onAuthenticated,
    super.key,
  });

  final ApiClient api;
  final Future<void> Function(AuthResult result) onAuthenticated;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _nickname = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_phone.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Введите телефон и пароль');
      return;
    }
    if (_register && _nickname.text.trim().isEmpty) {
      setState(() => _error = 'Введите никнейм');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = _register
          ? await widget.api.register(
              _phone.text.trim(),
              _password.text,
              _nickname.text.trim(),
            )
          : await widget.api.login(_phone.text.trim(), _password.text);
      await widget.onAuthenticated(result);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonScaffold(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'gru.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 58,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -3,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: _magenta, blurRadius: 22),
                        Shadow(color: _violet, blurRadius: 42),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Android preview for RuStore',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.68),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    _register ? 'Создать аккаунт' : 'Войти в GRU',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Телефон',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  if (_register) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nickname,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Никнейм',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Пароль',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFFF8FBF)),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _magenta,
                      foregroundColor: _ink,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _ink,
                            ),
                          )
                        : Text(_register ? 'Зарегистрироваться' : 'Войти'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _register = !_register;
                              _error = null;
                            }),
                    child: Text(
                      _register
                          ? 'У меня уже есть аккаунт'
                          : 'Создать новый аккаунт',
                    ),
                  ),
                  const SizedBox(height: 26),
                  const _SecurityNote(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _violet.withOpacity(.35)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: _violet),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Сессия хранится в защищённом хранилище Android. '
              'В release запрещён незашифрованный HTTP.',
              style: TextStyle(color: Colors.white70, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    required this.api,
    required this.currentUserId,
    required this.onLogout,
    super.key,
  });

  final ApiClient api;
  final String currentUserId;
  final Future<void> Function() onLogout;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<ChatSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.chats();
  }

  void _reload() {
    setState(() => _future = widget.api.chats());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonScaffold(
        child: RefreshIndicator(
          color: _magenta,
          backgroundColor: _panel,
          onRefresh: () async => _reload(),
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: _ink.withOpacity(.92),
                title: const Text(
                  'gru.',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Обновить',
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  IconButton(
                    tooltip: 'Выйти',
                    onPressed: () { widget.onLogout(); },
                    icon: const Icon(Icons.logout_rounded),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Чаты',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Android beta · ' + widget.api.baseUrl,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.55),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const _BetaBanner(),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverToBoxAdapter(
                  child: FutureBuilder<List<ChatSummary>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 70),
                          child: Center(
                            child: CircularProgressIndicator(color: _magenta),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return _ErrorCard(
                          message: snapshot.error.toString(),
                          onRetry: _reload,
                        );
                      }
                      final chats = snapshot.data ?? const <ChatSummary>[];
                      if (chats.isEmpty) {
                        return const _EmptyChats();
                      }
                      return Column(
                        children: [
                          for (final chat in chats)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ChatTile(
                                chat: chat,
                                currentUserId: widget.currentUserId,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ChatPage(
                                      api: widget.api,
                                      chat: chat,
                                      currentUserId: widget.currentUserId,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BetaBanner extends StatelessWidget {
  const _BetaBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _violet.withOpacity(.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _violet.withOpacity(.45)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: _magenta, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'История защищена серверным E2EE-контрактом. '
              'Android transport отправки подключается следующим шагом.',
              style: TextStyle(color: Colors.white70, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.chat,
    required this.currentUserId,
    required this.onTap,
  });

  final ChatSummary chat;
  final String currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = chat.titleFor(currentUserId);
    return Material(
      color: Colors.white.withOpacity(.06),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: _magenta.withOpacity(.18),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: _magenta.withOpacity(.18),
                child: Text(
                  title.isEmpty ? '?' : title.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: _magenta,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 70),
      child: Column(
        children: [
          Icon(Icons.forum_outlined, size: 64, color: _magenta.withOpacity(.75)),
          const SizedBox(height: 14),
          const Text(
            'Пока нет чатов',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Создайте первый диалог в iOS-клиенте GRU.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.redAccent.withOpacity(.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Не удалось загрузить чаты',
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({
    required this.api,
    required this.chat,
    required this.currentUserId,
    super.key,
  });

  final ApiClient api;
  final ChatSummary chat;
  final String currentUserId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late Future<List<ServerMessage>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.messages(widget.chat.id);
  }

  void _reload() {
    setState(() => _future = widget.api.messages(widget.chat.id));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.chat.titleFor(widget.currentUserId);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: _magenta.withOpacity(.18),
              child: Text(
                title.isEmpty ? '?' : title.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: _magenta, fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: NeonScaffold(
        child: Column(
          children: [
            const _BetaBanner(),
            Expanded(
              child: FutureBuilder<List<ServerMessage>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(color: _magenta),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: _ErrorCard(
                        message: snapshot.error.toString(),
                        onRetry: _reload,
                      ),
                    );
                  }
                  final messages = snapshot.data ?? const <ServerMessage>[];
                  if (messages.isEmpty) {
                    return const Center(
                      child: Text(
                        'Сообщений пока нет',
                        style: TextStyle(color: Colors.white60),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return _MessageBubble(
                        message: message,
                        isMine: message.senderId == widget.currentUserId,
                      );
                    },
                  );
                },
              ),
            ),
            const _ReadOnlyComposer(),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});
  final ServerMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 330),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: isMine ? _magenta.withOpacity(.20) : Colors.white.withOpacity(.08),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          border: Border.all(
            color: isMine ? _magenta.withOpacity(.45) : Colors.white12,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.displayText,
              style: const TextStyle(fontSize: 15, height: 1.3),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(message.createdAt),
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyComposer extends StatelessWidget {
  const _ReadOnlyComposer();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: _ink.withOpacity(.94),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(.08))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'E2EE-отправка готовится',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.lock_outline, color: _violet),
                  fillColor: Colors.white.withOpacity(.06),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const CircleAvatar(
              backgroundColor: Colors.white12,
              child: Icon(Icons.send_rounded, color: Colors.white38, size: 19),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(String? raw) {
  final date = DateTime.tryParse(raw ?? '')?.toLocal();
  if (date == null) return '';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day.$month ' + hour + ':' + minute;
}
