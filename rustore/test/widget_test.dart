import 'package:flutter_test/flutter_test.dart';
import 'package:gru_rustore/main.dart';

void main() {
  test('parses current GRU auth response', () {
    final result = AuthResult.fromJson({'token': 'jwt', 'userId': 'user-1'});
    expect(result.token, 'jwt');
    expect(result.userId, 'user-1');
  });

  test('chooses the other participant as chat title', () {
    final chat = ChatSummary.fromJson({
      'id': 'chat-1',
      'participants': [
        {'id': 'me', 'nickname': 'Marie'},
        {'id': 'peer', 'nickname': 'Alex'},
      ],
    });
    expect(chat.titleFor('me'), 'Alex');
  });

  test('does not expose encrypted payload as plaintext', () {
    final message = ServerMessage.fromJson({
      'id': 'message-1',
      'senderId': 'peer',
      'encryptedPayload': 'ciphertext',
    });
    expect(message.displayText, '🔒 Зашифрованное сообщение');
  });

  test('keeps only GRU themes in the picker', () {
    expect(kGruThemes.length, 9);
    expect(kGruThemes.any((theme) => theme.name == 'Ultraviolet Unicorn'), isTrue);
    expect(kGruThemes.any((theme) => theme.name == 'Black Moon Cat'), isTrue);
  });
}
