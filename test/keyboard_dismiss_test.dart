import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/controllers/music_controller.dart';
import 'package:spun_music/ui/artists.dart';
import 'support/queue_player.dart';

void main() {
  testWidgets('artist search dismisses touch keyboard outside and on submit', (
    tester,
  ) async {
    final music = MusicController(audioPlayer: QueuePlayer());
    addTearDown(music.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: ArtistsScreen(music: music),
      ),
    );
    final field = find.byType(TextField);
    await tester.tap(field);
    await tester.enterText(field, 'test');
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tap(find.text('Исполнитель не найден'));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(field);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
  });
}
