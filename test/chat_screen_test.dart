import 'package:spun_music/services/social_api.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:spun_music/services/chat_vault.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spun_music/controllers/music_controller.dart';
import 'package:spun_music/ui/chats.dart';
import 'support/queue_player.dart';

void main() {
  testWidgets('failed send preserves draft and retry uses the same key', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'socialToken': 'test'});
    final music = MusicController(audioPlayer: QueuePlayer())..loading = false;
    final keys = <String>[];
    FlutterSecureStorage.setMockInitialValues({});
    final seed = List<int>.filled(32, 7);
    await ChatVault.write('me', seed);
    final publicKey = await ChatVault.publicKey(seed);
    final peerKey = await ChatVault.publicKey(List<int>.filled(32, 9));
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: ChatScreen(
              id: 'abcdefghijklmnop',
              api: SocialApi(base: 'https://viora.example.com'),
              name: 'Друг',
              music: music,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Сообщение');
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Сообщение',
        );
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pumpAndSettle();
        expect(keys.length, 2);
        expect(keys[0], keys[1]);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
      () => MockClient((request) async {
        if (request.url.path == '/api/identity') {
          return http.Response(
            jsonEncode({'user': 'me', 'publicKey': publicKey}),
            200,
          );
        }
        if (request.url.path.endsWith('/security')) {
          return http.Response(
            jsonEncode({
              'user': 'me',
              'peer': 'friend',
              'peerKey': peerKey,
              'keyId': 'abc',
            }),
            200,
          );
        }
        if (request.method == 'POST') {
          expect(jsonDecode(request.body)['text'], isNull);
          expect(jsonDecode(request.body)['encrypted'], isNotNull);
          keys.add((jsonDecode(request.body) as Map)['nonce'] as String);
          return http.Response(
            keys.length == 1 ? '{"error":"offline"}' : '{"ok":true}',
            keys.length == 1 ? 503 : 200,
          );
        }
        return http.Response('{"messages":[]}', 200);
      }),
    );
    music.dispose();
  });
}
