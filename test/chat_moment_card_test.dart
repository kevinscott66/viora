import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/controllers/music_controller.dart';
import 'package:spun_music/models/track.dart';
import 'package:spun_music/services/moment_link.dart';
import 'package:spun_music/ui/chat_moment_card.dart';
import 'package:spun_music/ui/moment_reply.dart';
import 'package:spun_music/ui/lyrics_sheet.dart';
import 'package:spun_music/ui/moment_composer.dart';
import 'support/queue_player.dart';
import 'package:just_audio/just_audio.dart';

class MomentPlayer extends QueuePlayer {
  Duration captured = Duration.zero;
  @override
  Duration get position => captured;
  @override
  Future<Duration?> setAudioSources(
    List<AudioSource> sources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    ShuffleOrder? shuffleOrder,
  }) async {
    captured = initialPosition ?? Duration.zero;
    return super.setAudioSources(
      sources,
      initialIndex: initialIndex,
      initialPosition: initialPosition,
    );
  }
}

void main() {
  testWidgets(
    'card plays from moment and reply keeps conversation destination',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final music = MusicController(audioPlayer: MomentPlayer())
        ..ready = true
        ..loading = false;
      addTearDown(music.dispose);
      const track = Track(
        'one',
        'Example title 018',
        'Example artist 415',
        Colors.brown,
        durationMs: 120000,
        localUri: 'file:///one.mp3',
      );
      music.catalog.add(track);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: SingleChildScrollView(
                child: ChatMomentCard(
                  moment: const ReceivedMoment(
                    'Example title 018',
                    ['Example artist 415'],
                    31,
                    '',
                    lyric: 'Момент, который хочется сохранить',
                  ),
                  music: music,
                  chatId: 'room123',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expect(music.current.id, 'one');
      expect(music.position.inSeconds, 31);
      await tester.tap(find.text('Ответить песней'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.widget<MomentReplyScreen>(find.byType(MomentReplyScreen)).chatId,
        'room123',
      );
      await tester.tap(find.text('Example title 018').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.widget<LyricsScreen>(find.byType(LyricsScreen)).chatId,
        'room123',
      );
      await tester.tap(find.text('Написать свои слова'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.widget<MomentComposer>(find.byType(MomentComposer)).chatId,
        'room123',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
