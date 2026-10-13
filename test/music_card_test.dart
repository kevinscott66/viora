import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spun_music/models/music_card.dart';
import 'package:spun_music/controllers/music_controller.dart';
import 'package:spun_music/services/social_api.dart';
import 'package:spun_music/ui/music_card.dart';
import 'support/queue_player.dart';

Map<String, dynamic> sample() => {
  'v': 1,
  'name': 'Имя',
  'lyric': 'Строка',
  'theme': 'rose',
  'tracks': List.generate(
    3,
    (i) => {
      'v': 1,
      'title': 'Песня $i',
      'artists': ['Артист'],
      'seconds': 0,
      'note': '',
      'lyric': '',
    },
  ),
};

class CardApi extends SocialApi {
  final calls = <String>[];
  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
    bool auth = true,
  ]) async {
    calls.add(path);
    return path.endsWith('unpublish')
        ? {'ok': true}
        : {'url': 'https://viora.example.com/p/abcdefghijklmnop'};
  }
}

void main() {
  test('validates exact three distinct tracks, themes and text limits', () {
    expect(MusicCard.fromJson(sample()).toJson(), sample());
    final duplicate = sample();
    duplicate['tracks'] = List.filled(3, (sample()['tracks'] as List).first);
    for (final data in [
      duplicate,
      {...sample(), 'tracks': []},
      {...sample(), 'theme': 'bad'},
      {...sample(), 'name': ''},
      {...sample(), 'lyric': 'x' * 151},
    ]) {
      expect(() => MusicCard.fromJson(data), throwsFormatException);
    }
  });
  testWidgets('draft stays local until explicit publish; owner can revoke', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'musicCardDraft': jsonEncode(sample()),
    });
    final api = CardApi(), music = MusicController(audioPlayer: QueuePlayer());
    addTearDown(music.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MusicCardEditor(music: music, api: api),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.calls, isEmpty);
    await tester.enterText(find.byType(TextField).first, 'Новое имя');
    await tester.scrollUntilVisible(
      find.text('Сохранить черновик'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Сохранить черновик'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(api.calls, isEmpty);
    expect(
      jsonDecode(
        (await SharedPreferences.getInstance()).getString('musicCardDraft')!,
      )['name'],
      'Новое имя',
    );
    await tester.scrollUntilVisible(
      find.text('Опубликовать'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Опубликовать'));
    await tester.pumpAndSettle();
    expect(api.calls, ['/api/card']);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Отключить ссылку'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Отключить ссылку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отключить'));
    await tester.pumpAndSettle();
    expect(api.calls, ['/api/card', '/api/card/unpublish']);
    expect(
      (await SharedPreferences.getInstance()).getString(
        'musicCardPublishedUrl',
      ),
      isNull,
    );
    expect(
      (await SharedPreferences.getInstance()).getString('musicCardDraft'),
      isNotNull,
    );
  });
}
