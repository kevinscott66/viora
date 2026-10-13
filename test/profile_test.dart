import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/controllers/music_controller.dart';
import 'package:spun_music/services/social_api.dart';
import 'package:spun_music/ui/profile.dart';
import 'support/queue_player.dart';

class ProfileApi extends SocialApi {
  Map<String, dynamic>? saved;
  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
    bool auth = true,
  ]) async {
    if (path == '/api/sessions') return {'sessions': []};
    if (method == 'POST') {
      saved = body;
      return {};
    }
    return {
      'name': 'Listener',
      'bio': 'Music',
      'color': 'ocean',
      'hasRecovery': false,
    };
  }
}

void main() {
  testWidgets('profile loads and saves only explicit profile fields', (
    tester,
  ) async {
    final api = ProfileApi();
    final music = MusicController(audioPlayer: QueuePlayer());
    addTearDown(music.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(music: music, api: api),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Listener'), findsOneWidget);
    await tester.tap(find.text('Изменить профиль'));
    await tester.pumpAndSettle();
    expect(api.saved, isNull);
    await tester.enterText(find.byType(TextField).first, 'New name');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Сохранить профиль'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить профиль'));
    await tester.pumpAndSettle();
    expect(api.saved, {'name': 'New name', 'bio': 'Music', 'color': 'ocean'});
    expect(tester.takeException(), isNull);
  });
}
