import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/controllers/music_controller.dart';
import 'package:spun_music/models/track.dart';
import 'package:spun_music/services/moment_link.dart';
import 'package:spun_music/ui/received_moment.dart';
import 'package:spun_music/ui/moment_composer.dart';
import 'support/queue_player.dart';

void main() {
  testWidgets(
    'reply works without original song and leaves playback queue alone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final music = MusicController(audioPlayer: QueuePlayer())
        ..ready = true
        ..loading = false;
      addTearDown(music.dispose);
      const track = Track(
        'reply',
        'Мой ответ',
        'Artist',
        Colors.red,
        durationMs: 100000,
      );
      music.catalog.add(track);
      await tester.pumpWidget(
        MaterialApp(
          home: ReceivedMomentScreen(
            moment: const ReceivedMoment('Absent song', ['Unknown'], 32, ''),
            music: music,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final original = List.of(music.queue);
      await tester.tap(find.text('Ответить моментом'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Мой ответ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Написать свои слова'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(MomentComposer), findsOneWidget);
      expect(
        tester
            .widget<MomentComposer>(find.byType(MomentComposer))
            .replyTo!
            .title,
        'Absent song',
      );
      expect(music.queue, original);
      expect(tester.takeException(), isNull);
    },
  );
}
