import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

const _ink = Color(0xFF080711);
const _panel = Color(0xFF171126);
const _white = Colors.white;

void main() => runApp(const GruApp());

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);
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
      throw const ApiException('Сервер вернул неполный ответ авторизации', 200);
    }
    return AuthResult(token: token, userId: userId);
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

class ChatSummary {
  const ChatSummary({required this.id, required this.participants, this.createdAt});
  final String id;
  final List<Participant> participants;
  final String? createdAt;

  factory ChatSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['participants'] is List ? json['participants'] as List : const <dynamic>[];
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

class ServerMessage {
  const ServerMessage({
    required this.id,
    required this.senderId,
    this.text,
    this.encryptedPayload,
    this.createdAt,
    this.deletedAt,
    this.isEdited = false,
  });
  final String id;
  final String senderId;
  final String? text;
  final String? encryptedPayload;
  final String? createdAt;
  final String? deletedAt;
  final bool isEdited;

  factory ServerMessage.fromJson(Map<String, dynamic> json) => ServerMessage(
        id: (json['id'] ?? '').toString(),
        senderId: (json['senderId'] ?? '').toString(),
        text: json['text']?.toString(),
        encryptedPayload: json['encryptedPayload']?.toString(),
        createdAt: json['createdAt']?.toString(),
        deletedAt: json['deletedAt']?.toString(),
        isEdited: json['isEdited'] == true,
      );

  ServerMessage copyWith({String? deletedAt, String? text}) => ServerMessage(
        id: id,
        senderId: senderId,
        text: text ?? this.text,
        encryptedPayload: encryptedPayload,
        createdAt: createdAt,
        deletedAt: deletedAt ?? this.deletedAt,
        isEdited: isEdited,
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

class GruUser {
  const GruUser({required this.id, required this.nickname});
  final String id;
  final String nickname;

  factory GruUser.fromJson(Map<String, dynamic> json) => GruUser(
        id: (json['id'] ?? '').toString(),
        nickname: (json['nickname'] ?? '').toString(),
      );
}

class BotTurn {
  const BotTurn({required this.role, required this.text});
  final String role;
  final String text;

  Map<String, dynamic> toJson() => {'role': role, 'text': text};
}

class ThemePreset {
  const ThemePreset({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.background,
    required this.accent,
    required this.secondary,
    required this.motif,
  });
  final String id;
  final String name;
  final String subtitle;
  final Color background;
  final Color accent;
  final Color secondary;
  final String motif;
}

const kGruThemes = <ThemePreset>[
  ThemePreset(
    id: 'black-moon-cat',
    name: 'Black Moon Cat',
    subtitle: 'Вислоухие котодраконы в лунной пыли',
    background: Color(0xFF070912),
    accent: Color(0xFFB7C7FF),
    secondary: Color(0xFF7D6BFF),
    motif: 'moon',
  ),
  ThemePreset(
    id: 'neon-demon-cat',
    name: 'Neon Demon Cat',
    subtitle: 'Розовый неон, рожки и мягкие лапы',
    background: Color(0xFF120518),
    accent: Color(0xFFFF2BD6),
    secondary: Color(0xFF8B5CFF),
    motif: 'demon',
  ),
  ThemePreset(
    id: 'ultraviolet-unicorn',
    name: 'Ultraviolet Unicorn',
    subtitle: 'Котоединороги и тихие радуги',
    background: Color(0xFF100A35),
    accent: Color(0xFFB58CFF),
    secondary: Color(0xFF4DE8FF),
    motif: 'unicorn',
  ),
  ThemePreset(
    id: 'blood-dragon',
    name: 'Blood Dragon',
    subtitle: 'Красные чешуйки без лишнего шума',
    background: Color(0xFF180707),
    accent: Color(0xFFFF4B5C),
    secondary: Color(0xFFFF9A5C),
    motif: 'dragon',
  ),
  ThemePreset(
    id: 'forest-witch',
    name: 'Forest Witch',
    subtitle: 'Лесные коты, травы и мягкое свечение',
    background: Color(0xFF07150D),
    accent: Color(0xFFB5FF64),
    secondary: Color(0xFF5EE7A1),
    motif: 'witch',
  ),
  ThemePreset(
    id: 'cyber-midnight',
    name: 'Cyber Midnight',
    subtitle: 'Мини-коты среди тонких линий города',
    background: Color(0xFF050D1D),
    accent: Color(0xFF26D9FF),
    secondary: Color(0xFF775CFF),
    motif: 'cyber',
  ),
  ThemePreset(
    id: 'powder-princess',
    name: 'Powder Princess',
    subtitle: 'Пудровые лапки и прозрачные сердечки',
    background: Color(0xFF2A1021),
    accent: Color(0xFFFFA6D5),
    secondary: Color(0xFFFFD3E8),
    motif: 'powder',
  ),
  ThemePreset(
    id: 'green-acid-monster',
    name: 'Green Acid Monster',
    subtitle: 'Кислотные котодраконы в движении',
    background: Color(0xFF081405),
    accent: Color(0xFFB6FF2B),
    secondary: Color(0xFF4AFFA6),
    motif: 'acid',
  ),
  ThemePreset(
    id: 'iron-knight',
    name: 'Iron Knight',
    subtitle: 'Серебряные уши, щиты и звёзды',
    background: Color(0xFF11151E),
    accent: Color(0xFFDCE6FF),
    secondary: Color(0xFF7E8DAA),
    motif: 'knight',
  ),
];

ThemePreset themeById(String id) => kGruThemes.firstWhere(
      (theme) => theme.id == id,
      orElse: () => kGruThemes.first,
    );

class LocalProfile {
  const LocalProfile({this.nickname = 'Marie', this.bio = '', this.avatarPath});
  final String nickname;
  final String bio;
  final String? avatarPath;

  factory LocalProfile.fromJson(Map<String, dynamic> json) => LocalProfile(
        nickname: (json['nickname'] ?? 'Marie').toString(),
        bio: (json['bio'] ?? '').toString(),
        avatarPath: json['avatarPath']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'nickname': nickname,
        'bio': bio,
        'avatarPath': avatarPath,
      };
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
      request.headers['Authorization'] = 'Bearer ' + currentToken;
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

  Future<AuthResult> register(String phone, String password, String nickname) async {
    final json = await _request(
      'POST',
      '/auth/register',
      body: {'phone': phone, 'password': password, 'nickname': nickname},
    );
    return AuthResult.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<List<ChatSummary>> chats() async {
    final json = await _request('GET', '/chats');
    final list = json is List ? json : const <dynamic>[];
    return list
        .whereType<Map>()
        .map((item) => ChatSummary.fromJson(Map<String, dynamic>.from(item)))
        .where((chat) => chat.id.isNotEmpty)
        .toList();
  }

  Future<List<ServerMessage>> messages(String chatId) async {
    final json = await _request('GET', '/chats/' + Uri.encodeComponent(chatId) + '/messages');
    final list = json is List ? json : const <dynamic>[];
    return list
        .whereType<Map>()
        .map((item) => ServerMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<GruUser>> searchUsers(String query) async {
    final encoded = Uri.encodeQueryComponent(query.trim());
    final json = await _request('GET', '/users/search?nickname=' + encoded);
    final list = json is List ? json : const <dynamic>[];
    return list
        .whereType<Map>()
        .map((item) => GruUser.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<ChatSummary> createChat(String userId) async {
    final json = await _request('POST', '/chats', body: {'userId': userId});
    return ChatSummary.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<ServerMessage> deleteForMe(String messageId) async {
    final json = await _request('DELETE', '/messages/' + Uri.encodeComponent(messageId) + '/me');
    return ServerMessage.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<ServerMessage> deleteForEveryone(String messageId) async {
    final json = await _request('DELETE', '/messages/' + Uri.encodeComponent(messageId));
    return ServerMessage.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<String> botChat(String text, List<BotTurn> history) async {
    final json = await _request(
      'POST',
      '/bot/chat',
      body: {
        'text': text,
        'history': history.map((turn) => turn.toJson()).toList(),
      },
    );
    return (json as Map)['reply']?.toString() ?? 'GRU.bot не вернул ответ';
  }
}

class SecureSession {
  static final _storage = FlutterSecureStorage();

  Future<void> saveAuth(AuthResult result) => _storage.write(
        key: 'gru.auth',
        value: jsonEncode({'token': result.token, 'userId': result.userId}),
      );

  Future<AuthResult?> readAuth() async {
    final value = await _storage.read(key: 'gru.auth');
    if (value == null || value.isEmpty) return null;
    try {
      return AuthResult.fromJson(Map<String, dynamic>.from(jsonDecode(value) as Map));
    } catch (_) {
      await clearAuth();
      return null;
    }
  }

  Future<void> clearAuth() => _storage.delete(key: 'gru.auth');

  Future<void> saveTheme(ThemePreset theme) => _storage.write(key: 'gru.theme', value: theme.id);

  Future<ThemePreset> readTheme() async {
    return themeById(await _storage.read(key: 'gru.theme') ?? kGruThemes.first.id);
  }

  Future<void> saveProfile(LocalProfile profile) =>
      _storage.write(key: 'gru.profile', value: jsonEncode(profile.toJson()));

  Future<LocalProfile> readProfile() async {
    final value = await _storage.read(key: 'gru.profile');
    if (value == null || value.isEmpty) return const LocalProfile();
    try {
      return LocalProfile.fromJson(Map<String, dynamic>.from(jsonDecode(value) as Map));
    } catch (_) {
      return const LocalProfile();
    }
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
  ThemePreset _theme = kGruThemes.first;
  LocalProfile _profile = const LocalProfile();
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final auth = await _session.readAuth();
    final theme = await _session.readTheme();
    final profile = await _session.readProfile();
    if (!mounted) return;
    if (auth != null) _api.token = auth.token;
    setState(() {
      _auth = auth;
      _theme = theme;
      _profile = profile;
      _checking = false;
    });
  }

  Future<void> _signedIn(AuthResult auth) async {
    _api.token = auth.token;
    await _session.saveAuth(auth);
    if (!mounted) return;
    setState(() => _auth = auth);
  }

  Future<void> _signedOut() async {
    await _session.clearAuth();
    _api.token = null;
    if (!mounted) return;
    setState(() => _auth = null);
  }

  Future<void> _changeTheme(ThemePreset theme) async {
    await _session.saveTheme(theme);
    if (mounted) setState(() => _theme = theme);
  }

  Future<void> _changeProfile(LocalProfile profile) async {
    await _session.saveProfile(profile);
    if (mounted) setState(() => _profile = profile);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _theme.accent,
      brightness: Brightness.dark,
      surface: _theme.background,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'gru.',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _theme.background,
        colorScheme: colorScheme,
        appBarTheme: AppBarTheme(
          backgroundColor: _theme.background.withOpacity(.82),
          foregroundColor: _white,
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _panel.withOpacity(.82),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: BorderSide(color: _theme.accent, width: 1.2),
          ),
          labelStyle: const TextStyle(color: Colors.white70),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: _theme.background.withOpacity(.96),
          indicatorColor: _theme.accent.withOpacity(.22),
          labelTextStyle: MaterialStatePropertyAll(
            TextStyle(color: _theme.accent, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      home: _checking
          ? const _LoadingPage()
          : _auth == null
              ? AuthPage(api: _api, theme: _theme, onAuthenticated: _signedIn)
              : HomePage(
                  api: _api,
                  theme: _theme,
                  profile: _profile,
                  currentUserId: _auth!.userId,
                  onThemeChanged: _changeTheme,
                  onProfileChanged: _changeProfile,
                  onLogout: _signedOut,
                ),
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}

class AnimatedBackdrop extends StatefulWidget {
  const AnimatedBackdrop({required this.theme, required this.child, super.key});
  final ThemePreset theme;
  final Widget child;

  @override
  State<AnimatedBackdrop> createState() => _AnimatedBackdropState();
}

class _AnimatedBackdropState extends State<AnimatedBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: NeonWallpaperPainter(widget.theme, _controller.value),
            ),
            child!,
          ],
        ),
        child: widget.child,
      );
}

class NeonWallpaperPainter extends CustomPainter {
  NeonWallpaperPainter(this.theme, this.phase);
  final ThemePreset theme;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = Paint()
      ..shader = LinearGradient(
        colors: [theme.background, theme.background.withOpacity(.78), _ink],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRect(rect, gradient);

    final glow = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 5; i++) {
      final x = size.width * (0.12 + i * .23) + math.sin(phase * math.pi * 2 + i) * 30;
      final y = size.height * (0.18 + (i % 3) * .31);
      glow.color = theme.accent.withOpacity(.035);
      canvas.drawCircle(Offset(x, y), 70 + i * 13, glow);
    }

    final decor = Paint()
      ..color = theme.secondary.withOpacity(.38)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 18; i++) {
      final x = ((i * 83) % math.max(1, size.width.toInt())).toDouble();
      final y = ((i * 137) % math.max(1, size.height.toInt())).toDouble();
      final twinkle = .6 + .4 * math.sin(phase * math.pi * 2 + i);
      canvas.drawCircle(Offset(x, y), 1.5 + twinkle * 1.5, decor);
    }

    for (var i = 0; i < 25; i++) {
      final x = ((i * 97 + 28) % math.max(1, size.width.toInt())).toDouble();
      final y = ((i * 61 + 44) % math.max(1, size.height.toInt())).toDouble();
      final bob = math.sin(phase * math.pi * 2 + i * .73) * 4;
      final scale = .42 + (i % 4) * .08;
      _drawMiniCat(canvas, Offset(x, y + bob), scale, theme.accent, theme.secondary, i);
    }

    if (theme.motif == 'cyber') {
      final grid = Paint()
        ..color = theme.accent.withOpacity(.08)
        ..strokeWidth = .7;
      for (var x = 0.0; x < size.width; x += 38) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      }
      for (var y = 0.0; y < size.height; y += 38) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      }
    }
  }

  void _drawMiniCat(
    Canvas canvas,
    Offset center,
    double scale,
    Color color,
    Color secondary,
    int index,
  ) {
    final s = 20 * scale;
    final line = Paint()
      ..color = color.withOpacity(.62)
      ..strokeWidth = 1.2 * scale
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = color.withOpacity(.12);
    final head = Rect.fromCenter(center: center.translate(0, -s * .25), width: s * 1.15, height: s * .9);
    canvas.drawOval(head, fill);
    canvas.drawOval(head, line);
    final leftEar = Path()
      ..moveTo(center.dx - s * .55, center.dy - s * .5)
      ..quadraticBezierTo(center.dx - s * .72, center.dy - s * 1.1, center.dx - s * .2, center.dy - s * .7)
      ..close();
    final rightEar = Path()
      ..moveTo(center.dx + s * .55, center.dy - s * .5)
      ..quadraticBezierTo(center.dx + s * .72, center.dy - s * 1.1, center.dx + s * .2, center.dy - s * .7)
      ..close();
    canvas.drawPath(leftEar, line);
    canvas.drawPath(rightEar, line);
    canvas.drawCircle(center.translate(-s * .2, -s * .3), s * .05, line);
    canvas.drawCircle(center.translate(s * .2, -s * .3), s * .05, line);

    final body = Rect.fromCenter(center: center.translate(0, s * .55), width: s * .78, height: s * .9);
    canvas.drawOval(body, fill);
    canvas.drawOval(body, line);
    final tail = Path()
      ..moveTo(center.dx + s * .35, center.dy + s * .7)
      ..cubicTo(center.dx + s * 1.2, center.dy + s * .9, center.dx + s * 1.15, center.dy + s * .05, center.dx + s * .8, center.dy + s * .15);
    canvas.drawPath(tail, line);

    if (theme.motif == 'dragon' || theme.motif == 'demon' || theme.motif == 'acid') {
      final wing = Path()
        ..moveTo(center.dx - s * .3, center.dy + s * .2)
        ..lineTo(center.dx - s * 1.05, center.dy - s * .1)
        ..lineTo(center.dx - s * .7, center.dy + s * .6)
        ..close();
      canvas.drawPath(wing, line);
      canvas.drawPath(wing.shift(Offset(s * 1.3, 0)), line);
    }
    if (theme.motif == 'unicorn') {
      final horn = Path()
        ..moveTo(center.dx + s * .25, center.dy - s * .75)
        ..lineTo(center.dx + s * .65, center.dy - s * 1.35)
        ..lineTo(center.dx + s * .5, center.dy - s * .62);
      canvas.drawPath(horn, line);
    }
    if (theme.motif == 'moon' || index % 7 == 0) {
      final moon = Paint()..color = secondary.withOpacity(.36);
      canvas.drawCircle(center.translate(s * 1.25, -s * .85), s * .25, moon);
    }
    if (theme.motif == 'witch' && index % 3 == 0) {
      final hat = Path()
        ..moveTo(center.dx - s * .6, center.dy - s * .8)
        ..lineTo(center.dx, center.dy - s * 1.45)
        ..lineTo(center.dx + s * .6, center.dy - s * .8)
        ..close();
      canvas.drawPath(hat, line);
    }
    if (theme.motif == 'knight' && index % 4 == 0) {
      canvas.drawRect(Rect.fromCenter(center: center.translate(-s * .95, s * .1), width: s * .35, height: s * .48), line);
    }
  }

  @override
  bool shouldRepaint(covariant NeonWallpaperPainter oldDelegate) =>
      oldDelegate.theme.id != theme.id || oldDelegate.phase != phase;
}

class AuthPage extends StatefulWidget {
  const AuthPage({required this.api, required this.theme, required this.onAuthenticated, super.key});
  final ApiClient api;
  final ThemePreset theme;
  final Future<void> Function(AuthResult) onAuthenticated;

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
          ? await widget.api.register(_phone.text.trim(), _password.text, _nickname.text.trim())
          : await widget.api.login(_phone.text.trim(), _password.text);
      await widget.onAuthenticated(result);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: widget.theme.background,
        body: AnimatedBackdrop(
          theme: widget.theme,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'gru.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 58,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -3,
                          color: _white,
                          shadows: [
                            Shadow(color: widget.theme.accent, blurRadius: 22),
                            Shadow(color: widget.theme.secondary, blurRadius: 42),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Current GRU Android preview',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _white.withOpacity(.68), fontSize: 15),
                      ),
                      const SizedBox(height: 36),
                      Text(
                        _register ? 'Создать аккаунт' : 'Войти в GRU',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Телефон', prefixIcon: Icon(Icons.phone_outlined)),
                      ),
                      if (_register) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nickname,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Никнейм', prefixIcon: Icon(Icons.alternate_email)),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        onSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(labelText: 'Пароль', prefixIcon: Icon(Icons.lock_outline)),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(_error!, style: const TextStyle(color: Color(0xFFFF8FBF))),
                      ],
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: widget.theme.accent,
                          foregroundColor: _ink,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _busy
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(_register ? 'Зарегистрироваться' : 'Войти'),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _register = !_register;
                                  _error = null;
                                }),
                        child: Text(_register ? 'У меня уже есть аккаунт' : 'Создать новый аккаунт'),
                      ),
                      const SizedBox(height: 18),
                      _SecurityCard(theme: widget.theme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({required this.theme});
  final ThemePreset theme;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _white.withOpacity(.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.secondary.withOpacity(.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, color: theme.accent),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Сессия хранится в Android Keystore. Release использует HTTPS; plaintext-отправка намеренно выключена.',
                style: TextStyle(color: Colors.white70, height: 1.35),
              ),
            ),
          ],
        ),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({
    required this.api,
    required this.theme,
    required this.profile,
    required this.currentUserId,
    required this.onThemeChanged,
    required this.onProfileChanged,
    required this.onLogout,
    super.key,
  });
  final ApiClient api;
  final ThemePreset theme;
  final LocalProfile profile;
  final String currentUserId;
  final Future<void> Function(ThemePreset) onThemeChanged;
  final Future<void> Function(LocalProfile) onProfileChanged;
  final Future<void> Function() onLogout;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  late Future<List<ChatSummary>> _chats;

  @override
  void initState() {
    super.initState();
    _chats = widget.api.chats();
  }

  void _reloadChats() => setState(() => _chats = widget.api.chats());

  @override
  Widget build(BuildContext context) {
    final title = _tab == 0 ? 'Чаты' : _tab == 1 ? 'Люди' : 'Настройки';
    return Scaffold(
      backgroundColor: widget.theme.background,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (_tab == 0)
            IconButton(
              tooltip: 'GRU.bot',
              icon: NeonCircleIcon(icon: Icons.auto_awesome, color: widget.theme.accent),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => GRUBotPage(api: widget.api, theme: widget.theme)),
              ),
            ),
          if (_tab == 2)
            IconButton(
              tooltip: 'Профиль',
              icon: AvatarCircle(profile: widget.profile, theme: widget.theme, size: 34),
              onPressed: () => _openProfile(context),
            ),
        ],
      ),
      body: AnimatedBackdrop(
        theme: widget.theme,
        child: SafeArea(
          top: false,
          child: IndexedStack(
            index: _tab,
            children: [
              ChatsPage(
                api: widget.api,
                theme: widget.theme,
                currentUserId: widget.currentUserId,
                chats: _chats,
                onReload: _reloadChats,
              ),
              PeoplePage(api: widget.api, theme: widget.theme, onChatCreated: _reloadChats),
              SettingsPage(
                theme: widget.theme,
                profile: widget.profile,
                apiBaseUrl: widget.api.baseUrl,
                onThemeChanged: widget.onThemeChanged,
                onProfileTap: () => _openProfile(context),
                onLogout: widget.onLogout,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: [
          NavigationDestination(
            icon: NeonCircleIcon(icon: Icons.forum_outlined, color: widget.theme.accent),
            selectedIcon: NeonCircleIcon(icon: Icons.forum, color: widget.theme.accent, filled: true),
            label: 'Чаты',
          ),
          NavigationDestination(
            icon: NeonCircleIcon(icon: Icons.people_outline, color: widget.theme.accent),
            selectedIcon: NeonCircleIcon(icon: Icons.people, color: widget.theme.accent, filled: true),
            label: 'Люди',
          ),
          NavigationDestination(
            icon: NeonCircleIcon(icon: Icons.tune, color: widget.theme.accent),
            selectedIcon: NeonCircleIcon(icon: Icons.tune, color: widget.theme.accent, filled: true),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          theme: widget.theme,
          profile: widget.profile,
          onSaved: widget.onProfileChanged,
        ),
      ),
    );
  }
}

class ChatsPage extends StatelessWidget {
  const ChatsPage({
    required this.api,
    required this.theme,
    required this.currentUserId,
    required this.chats,
    required this.onReload,
    super.key,
  });
  final ApiClient api;
  final ThemePreset theme;
  final String currentUserId;
  final Future<List<ChatSummary>> chats;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ChatSummary>>(
        future: chats,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorCard(message: snapshot.error.toString(), onRetry: onReload, theme: theme);
          }
          final items = snapshot.data ?? const <ChatSummary>[];
          return RefreshIndicator(
            onRefresh: () async => onReload(),
            color: theme.accent,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _BotCard(theme: theme, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GRUBotPage(api: api, theme: theme)))),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  _EmptyCard(theme: theme)
                else
                  ...items.map(
                    (chat) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _ChatCard(
                        title: chat.titleFor(currentUserId),
                        subtitle: 'E2EE history • ' + chat.id,
                        theme: theme,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatPage(
                              api: api,
                              theme: theme,
                              chat: chat,
                              currentUserId: currentUserId,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
}

class _BotCard extends StatelessWidget {
  const _BotCard({required this.theme, required this.onTap});
  final ThemePreset theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [theme.accent.withOpacity(.28), theme.secondary.withOpacity(.18)]),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.accent.withOpacity(.5)),
            boxShadow: [BoxShadow(color: theme.accent.withOpacity(.15), blurRadius: 28)],
          ),
          child: Row(
            children: [
              NeonCircleIcon(icon: Icons.auto_awesome, color: theme.accent, filled: true, size: 48),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GRU.bot', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text('Встроенный собеседник с локальным fallback', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      );
}

class _ChatCard extends StatelessWidget {
  const _ChatCard({required this.title, required this.subtitle, required this.theme, required this.onTap});
  final String title;
  final String subtitle;
  final ThemePreset theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        tileColor: _white.withOpacity(.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: theme.secondary.withOpacity(.18))),
        leading: NeonCircleIcon(icon: Icons.chat_bubble_outline, color: theme.accent, size: 44),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.theme});
  final ThemePreset theme;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(color: _white.withOpacity(.05), borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            Icon(Icons.forum_outlined, size: 40, color: theme.accent),
            const SizedBox(height: 12),
            const Text('Чатов пока нет', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Открой «Люди», найди пользователя GRU и создай диалог.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry, required this.theme});
  final String message;
  final VoidCallback onRetry;
  final ThemePreset theme;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 42, color: theme.accent),
              const SizedBox(height: 12),
              const Text('Backend недоступен', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
              const SizedBox(height: 14),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Повторить')),
            ],
          ),
        ),
      );
}

class PeoplePage extends StatefulWidget {
  const PeoplePage({required this.api, required this.theme, required this.onChatCreated, super.key});
  final ApiClient api;
  final ThemePreset theme;
  final VoidCallback onChatCreated;

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  final _query = TextEditingController();
  List<GruUser> _users = const [];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final value = _query.text.trim();
    if (value.length < 2) {
      setState(() => _error = 'Введите минимум 2 символа');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final users = await widget.api.searchUsers(value);
      if (mounted) setState(() => _users = users);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startChat(GruUser user) async {
    try {
      await widget.api.createChat(user.id);
      if (!mounted) return;
      widget.onChatCreated();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Чат с @' + user.nickname + ' создан')));
    } on Object catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
        children: [
          TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Найти пользователя GRU',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _busy
                  ? const Padding(padding: EdgeInsets.all(13), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                  : IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward)),
            ),
          ),
          const SizedBox(height: 14),
          _PeopleInfoCard(theme: widget.theme),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFFFF8FBF))),
          ],
          const SizedBox(height: 14),
          if (!_busy && _users.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Здесь будут контакты, которые уже есть в GRU.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
            )
          else
            ..._users.map(
              (user) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  tileColor: _white.withOpacity(.06),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                  leading: NeonCircleIcon(icon: Icons.person_outline, color: widget.theme.accent, size: 42),
                  title: Text('@' + user.nickname, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(user.id, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54)),
                  trailing: FilledButton(onPressed: () => _startChat(user), child: const Text('Чат')),
                ),
              ),
            ),
        ],
      );
}

class _PeopleInfoCard extends StatelessWidget {
  const _PeopleInfoCard({required this.theme});
  final ThemePreset theme;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.secondary.withOpacity(.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.secondary.withOpacity(.28)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.people_alt_outlined),
            SizedBox(width: 12),
            Expanded(child: Text('Поиск идёт по пользователям, зарегистрированным в GRU. Телефонная книга не отправляется на сервер.', style: TextStyle(color: Colors.white70, height: 1.35))),
          ],
        ),
      );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.theme,
    required this.profile,
    required this.apiBaseUrl,
    required this.onThemeChanged,
    required this.onProfileTap,
    required this.onLogout,
    super.key,
  });
  final ThemePreset theme;
  final LocalProfile profile;
  final String apiBaseUrl;
  final Future<void> Function(ThemePreset) onThemeChanged;
  final VoidCallback onProfileTap;
  final Future<void> Function() onLogout;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool readReceipts = true;
  bool messagePreview = false;
  bool appLock = false;
  bool reduceMotion = false;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          InkWell(
            onTap: widget.onProfileTap,
            borderRadius: BorderRadius.circular(21),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _white.withOpacity(.07), borderRadius: BorderRadius.circular(21), border: Border.all(color: widget.theme.accent.withOpacity(.25))),
              child: Row(
                children: [
                  AvatarCircle(profile: widget.profile, theme: widget.theme, size: 64),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.profile.nickname, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(widget.profile.bio.isEmpty ? 'Добавить био' : widget.profile.bio, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle('Темы GRU'),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kGruThemes.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.32),
            itemBuilder: (context, index) {
              final theme = kGruThemes[index];
              final selected = theme.id == widget.theme.id;
              return InkWell(
                onTap: () => widget.onThemeChanged(theme),
                borderRadius: BorderRadius.circular(17),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [theme.background, theme.secondary.withOpacity(.34)]),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: selected ? theme.accent : theme.secondary.withOpacity(.25), width: selected ? 2 : 1),
                    boxShadow: selected ? [BoxShadow(color: theme.accent.withOpacity(.28), blurRadius: 16)] : null,
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    NeonCircleIcon(icon: Icons.pets, color: theme.accent, filled: selected, size: 32),
                    const Spacer(),
                    Text(theme.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(theme.motif, style: TextStyle(color: theme.accent.withOpacity(.8), fontSize: 11)),
                  ]),
                ),
              );
            },
          ),
          const SizedBox(height: 22),
          const _SectionTitle('Приватность и комфорт'),
          SwitchListTile.adaptive(value: readReceipts, onChanged: (value) => setState(() => readReceipts = value), title: const Text('Read receipts'), subtitle: const Text('Показывать статус прочтения', style: TextStyle(color: Colors.white54))),
          SwitchListTile.adaptive(value: messagePreview, onChanged: (value) => setState(() => messagePreview = value), title: const Text('Предпросмотр сообщений'), subtitle: const Text('Скрывать текст в уведомлениях', style: TextStyle(color: Colors.white54))),
          SwitchListTile.adaptive(value: appLock, onChanged: (value) => setState(() => appLock = value), title: const Text('App lock'), subtitle: const Text('Биометрия будет подключена в следующем Android pass', style: TextStyle(color: Colors.white54))),
          SwitchListTile.adaptive(value: reduceMotion, onChanged: (value) => setState(() => reduceMotion = value), title: const Text('Уменьшить анимацию'), subtitle: const Text('Оставить статичный фон', style: TextStyle(color: Colors.white54))),
          const SizedBox(height: 12),
          _SecurityCard(theme: widget.theme),
          const SizedBox(height: 12),
          ListTile(
            tileColor: _white.withOpacity(.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: Icon(Icons.cloud_outlined, color: widget.theme.accent),
            title: const Text('Backend'),
            subtitle: Text(widget.apiBaseUrl, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60)),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(onPressed: () { widget.onLogout(); }, icon: const Icon(Icons.logout), label: const Text('Выйти из аккаунта')),
          const SizedBox(height: 12),
          const Center(child: Text('gru. • people for people • Android beta', style: TextStyle(color: Colors.white38, fontSize: 12))),
        ],
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700));
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({required this.theme, required this.profile, required this.onSaved, super.key});
  final ThemePreset theme;
  final LocalProfile profile;
  final Future<void> Function(LocalProfile) onSaved;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final _nickname = TextEditingController(text: widget.profile.nickname);
  late final _bio = TextEditingController(text: widget.profile.bio);
  String? _avatarPath;
  bool _saving = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _avatarPath = widget.profile.avatarPath;
  }

  @override
  void dispose() {
    _nickname.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 88, maxWidth: 1200);
      if (file != null && mounted) setState(() => _avatarPath = file.path);
    } on Object catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _save() async {
    final nickname = _nickname.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Никнейм не может быть пустым')));
      return;
    }
    setState(() => _saving = true);
    await widget.onSaved(LocalProfile(nickname: nickname, bio: _bio.text.trim(), avatarPath: _avatarPath));
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: widget.theme.background,
        appBar: AppBar(title: const Text('Профиль')),
        body: AnimatedBackdrop(
          theme: widget.theme,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
            children: [
              Center(child: AvatarCircle(profile: LocalProfile(nickname: _nickname.text, avatarPath: _avatarPath), theme: widget.theme, size: 116)),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                OutlinedButton.icon(onPressed: () => _pick(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Библиотека')),
                const SizedBox(width: 10),
                OutlinedButton.icon(onPressed: () => _pick(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: const Text('Камера')),
              ]),
              const SizedBox(height: 26),
              TextField(controller: _nickname, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Никнейм', prefixIcon: Icon(Icons.alternate_email))),
              const SizedBox(height: 14),
              TextField(controller: _bio, maxLines: 4, maxLength: 160, decoration: const InputDecoration(labelText: 'Био', alignLabelWithHint: true, prefixIcon: Icon(Icons.edit_note_outlined))),
              const SizedBox(height: 10),
              const Text('Профиль и выбранный аватар сохраняются локально в защищённом хранилище этой Android-беты.', style: TextStyle(color: Colors.white60, height: 1.35)),
              const SizedBox(height: 22),
              FilledButton(onPressed: _saving ? null : _save, child: _saving ? const CircularProgressIndicator() : const Text('Сохранить')),
            ],
          ),
        ),
      );
}

class AvatarCircle extends StatelessWidget {
  const AvatarCircle({required this.profile, required this.theme, this.size = 48, super.key});
  final LocalProfile profile;
  final ThemePreset theme;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = profile.avatarPath;
    final hasImage = path != null && path!.isNotEmpty && File(path).existsSync();
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.secondary.withOpacity(.26),
        border: Border.all(color: theme.accent.withOpacity(.85), width: 1.5),
        boxShadow: [BoxShadow(color: theme.accent.withOpacity(.25), blurRadius: 15)],
      ),
      child: hasImage
          ? Image.file(File(path!), fit: BoxFit.cover)
          : Center(child: profile.nickname.trim().isEmpty ? Icon(Icons.pets, color: theme.accent, size: size * .42) : Text(profile.nickname.trim().substring(0, 1).toUpperCase(), style: TextStyle(color: theme.accent, fontSize: size * .38, fontWeight: FontWeight.w800))),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({required this.api, required this.theme, required this.chat, required this.currentUserId, super.key});
  final ApiClient api;
  final ThemePreset theme;
  final ChatSummary chat;
  final String currentUserId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late Future<List<ServerMessage>> _future;
  List<ServerMessage>? _items;

  @override
  void initState() {
    super.initState();
    _future = widget.api.messages(widget.chat.id);
  }

  void _reload() => setState(() {
        _items = null;
        _future = widget.api.messages(widget.chat.id);
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: widget.theme.background,
        appBar: AppBar(title: Text(widget.chat.titleFor(widget.currentUserId))),
        body: AnimatedBackdrop(
          theme: widget.theme,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: FutureBuilder<List<ServerMessage>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      if (snapshot.hasError) return _ErrorCard(message: snapshot.error.toString(), onRetry: _reload, theme: widget.theme);
                      final list = _items ?? snapshot.data ?? const <ServerMessage>[];
                      _items ??= List<ServerMessage>.from(list);
                      if (list.isEmpty) return const Center(child: Text('История пока пуста', style: TextStyle(color: Colors.white60)));
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final message = list[index];
                          return _MessageBubble(
                            message: message,
                            mine: message.senderId == widget.currentUserId,
                            theme: widget.theme,
                            onLongPress: () => _messageActions(message),
                          );
                        },
                      );
                    },
                  ),
                ),
                _ReadOnlyComposer(theme: widget.theme),
              ],
            ),
          ),
        ),
      );

  Future<void> _messageActions(ServerMessage message) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: widget.theme.background,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Удалить у меня'), onTap: () => Navigator.pop(context, 'me')),
          if (message.senderId == widget.currentUserId)
            ListTile(leading: const Icon(Icons.delete_forever), title: const Text('Удалить у всех'), onTap: () => Navigator.pop(context, 'everyone')),
          ListTile(leading: const Icon(Icons.close), title: const Text('Отмена'), onTap: () => Navigator.pop(context)),
        ]),
      ),
    );
    if (!mounted || choice == null) return;
    try {
      final updated = choice == 'me' ? await widget.api.deleteForMe(message.id) : await widget.api.deleteForEveryone(message.id);
      if (!mounted) return;
      setState(() {
        final items = _items;
        if (items == null) return;
        if (choice == 'me') {
          items.removeWhere((item) => item.id == message.id);
        } else {
          final index = items.indexWhere((item) => item.id == message.id);
          if (index >= 0) items[index] = updated;
        }
      });
    } on Object catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine, required this.theme, required this.onLongPress});
  final ServerMessage message;
  final bool mine;
  final ThemePreset theme;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) => Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 330),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: mine ? theme.accent.withOpacity(.28) : _white.withOpacity(.08),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(17),
                topRight: const Radius.circular(17),
                bottomLeft: Radius.circular(mine ? 17 : 4),
                bottomRight: Radius.circular(mine ? 4 : 17),
              ),
              border: Border.all(color: mine ? theme.accent.withOpacity(.46) : _white.withOpacity(.12)),
            ),
            child: Text(message.displayText, style: TextStyle(color: message.deletedAt == null ? _white : Colors.white54, fontStyle: message.deletedAt == null ? FontStyle.normal : FontStyle.italic, height: 1.3)),
          ),
        ),
      );
}

class _ReadOnlyComposer extends StatelessWidget {
  const _ReadOnlyComposer({required this.theme});
  final ThemePreset theme;

  void _explain(BuildContext context) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Android transport ждёт E2EE envelope; plaintext не включаем.')));

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(color: theme.background.withOpacity(.94), border: Border(top: BorderSide(color: theme.secondary.withOpacity(.25)))),
        child: Column(children: [
          Row(children: [
            IconButton(onPressed: () => _explain(context), icon: Icon(Icons.add_circle_outline, color: theme.accent)),
            Expanded(child: TextField(enabled: false, decoration: InputDecoration(hintText: 'E2EE-отправка готовится', hintStyle: const TextStyle(color: Colors.white54), fillColor: _white.withOpacity(.07), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11)))),
            IconButton(onPressed: () => _explain(context), icon: Icon(Icons.pets, color: theme.accent)),
            IconButton(onPressed: () => _explain(context), icon: Icon(Icons.mic_none, color: theme.accent)),
          ]),
          const SizedBox(height: 2),
          const Text('Голос, видео и кружок будут отправляться только через E2EE media envelope.', style: TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
      );
}

class GRUBotPage extends StatefulWidget {
  const GRUBotPage({required this.api, required this.theme, super.key});
  final ApiClient api;
  final ThemePreset theme;

  @override
  State<GRUBotPage> createState() => _GRUBotPageState();
}

class _GRUBotPageState extends State<GRUBotPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<BotTurn> _turns = [];
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    _input.clear();
    setState(() {
      _busy = true;
      _turns.add(BotTurn(role: 'user', text: text));
    });
    try {
      final reply = await widget.api.botChat(text, _turns);
      if (mounted) setState(() => _turns.add(BotTurn(role: 'assistant', text: reply)));
    } on Object catch (error) {
      if (mounted) setState(() => _turns.add(BotTurn(role: 'assistant', text: error.toString())));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await Future<void>.delayed(const Duration(milliseconds: 40));
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: widget.theme.background,
        appBar: AppBar(title: const Text('GRU.bot')),
        body: AnimatedBackdrop(
          theme: widget.theme,
          child: SafeArea(
            top: false,
            child: Column(children: [
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                  children: [
                    _BotIntro(theme: widget.theme),
                    const SizedBox(height: 14),
                    ..._turns.map((turn) => _BotBubble(turn: turn, theme: widget.theme)),
                    if (_busy) const Padding(padding: EdgeInsets.all(16), child: Align(alignment: Alignment.centerLeft, child: CircularProgressIndicator())),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                decoration: BoxDecoration(color: widget.theme.background.withOpacity(.94), border: Border(top: BorderSide(color: widget.theme.secondary.withOpacity(.25)))),
                child: Row(children: [
                  Expanded(child: TextField(controller: _input, textInputAction: TextInputAction.send, onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'Спросить GRU.bot'))),
                  const SizedBox(width: 8),
                  IconButton(onPressed: _busy ? null : _send, icon: NeonCircleIcon(icon: Icons.arrow_upward, color: widget.theme.accent, filled: true)),
                ]),
              ),
            ]),
          ),
        ),
      );
}

class _BotIntro extends StatelessWidget {
  const _BotIntro({required this.theme});
  final ThemePreset theme;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: theme.accent.withOpacity(.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.accent.withOpacity(.3))),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.auto_awesome),
          SizedBox(width: 12),
          Expanded(child: Text('Я встроенный агент GRU: могу поддержать разговор, помочь с текстом или собрать план. Если провайдер недоступен, работает локальный fallback.', style: TextStyle(color: Colors.white70, height: 1.35))),
        ]),
      );
}

class _BotBubble extends StatelessWidget {
  const _BotBubble({required this.turn, required this.theme});
  final BotTurn turn;
  final ThemePreset theme;

  @override
  Widget build(BuildContext context) {
    final mine = turn.role == 'user';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: mine ? theme.accent.withOpacity(.25) : _white.withOpacity(.08), borderRadius: BorderRadius.circular(17)),
        child: Text(turn.text, style: const TextStyle(height: 1.35)),
      ),
    );
  }
}

class NeonCircleIcon extends StatelessWidget {
  const NeonCircleIcon({required this.icon, required this.color, this.size = 38, this.filled = false, super.key});
  final IconData icon;
  final Color color;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color.withOpacity(.22) : Colors.transparent,
          border: Border.all(color: color.withOpacity(.85), width: 1.2),
          boxShadow: [BoxShadow(color: color.withOpacity(.28), blurRadius: 12)],
        ),
        child: Icon(icon, size: size * .48, color: color),
      );
}
