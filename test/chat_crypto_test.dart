import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/services/chat_crypto.dart';

void main() {
  test('cipher authenticates room, sender, nonce, key and tampering', () async {
    final key = List<int>.generate(32, (i) => i);
    final payload = {
      'text': 'private message',
      'moment': {'title': 'private song'},
    };
    final e = await ChatCipher.encrypt(key, 'room', 'sender', 'nonce', payload);
    expect(
      await ChatCipher.decrypt(key, 'room', 'sender', 'nonce', e),
      payload,
    );
    for (final args in [
      ['other', 'sender', 'nonce'],
      ['room', 'other', 'nonce'],
      ['room', 'sender', 'other'],
    ]) {
      await expectLater(
        ChatCipher.decrypt(key, args[0], args[1], args[2], e),
        throwsA(anything),
      );
    }
    await expectLater(
      ChatCipher.decrypt(List.filled(32, 8), 'room', 'sender', 'nonce', e),
      throwsA(anything),
    );
    await expectLater(
      ChatCipher.decrypt(key, 'room', 'sender', 'nonce', {
        ...e,
        'tag': 'AAAAAAAAAAAAAAAAAAAAAA==',
      }),
      throwsA(anything),
    );
    final second = await ChatCipher.encrypt(
      key,
      'room',
      'sender',
      'nonce',
      payload,
    );
    expect(second['iv'], isNot(e['iv']));
  });
}
