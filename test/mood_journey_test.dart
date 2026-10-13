import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spun_music/controllers/music_controller.dart';
import 'package:spun_music/models/track.dart';
import 'package:spun_music/services/mood_journey.dart';
import 'package:spun_music/ui/mood_journey.dart';
import 'support/queue_player.dart';

Track song(int n, {int minutes = 3}) => Track(
  '$n',
  'Song $n',
  'Artist',
  Colors.blue,
  localUri: 'file:///$n.mp3',
  durationMs: minutes * 60000,
);
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'only annotated playable recordings, no duplicates, gradual both ways',
    () {
      final tracks = List.generate(12, song);
      final labels = {
        for (var i = 0; i < 9; i++) '$i': TrackMood.values[i % 3],
      };
      for (final reverse in [false, true]) {
        final result = buildMoodJourney(
          [...tracks, tracks.first],
          labels,
          reverse ? TrackMood.energetic : TrackMood.calm,
          reverse ? TrackMood.calm : TrackMood.energetic,
          const Duration(minutes: 20),
          random: Random(1),
        );
        expect(result.length, 7);
        expect(result.map((t) => t.id).toSet().length, result.length);
        expect(result.every((t) => labels.containsKey(t.id)), isTrue);
        final moods = result.map((t) => labels[t.id]!.index).toList();
        expect(moods.first, reverse ? 2 : 0);
        expect(moods.last, reverse ? 0 : 2);
        for (var i = 1; i < moods.length; i++) {
          expect(
            reverse ? moods[i] <= moods[i - 1] : moods[i] >= moods[i - 1],
            isTrue,
          );
        }
      }
    },
  );
  test(
    'same mood excludes other moods; empty labels produce no fake match',
    () {
      final tracks = [song(0), song(1)];
      expect(
        buildMoodJourney(
          tracks,
          {},
          TrackMood.calm,
          TrackMood.energetic,
          const Duration(minutes: 20),
        ),
        isEmpty,
      );
      expect(
        buildMoodJourney(
          tracks,
          {'0': TrackMood.calm, '1': TrackMood.energetic},
          TrackMood.calm,
          TrackMood.calm,
          const Duration(minutes: 20),
        ).map((t) => t.id),
        ['0'],
      );
    },
  );
  test(
    'whole tracks approximate duration and shorter final track is considered',
    () {
      final tracks = [
        song(0, minutes: 8),
        song(1, minutes: 9),
        song(2, minutes: 2),
      ];
      final result = buildMoodJourney(
        tracks,
        {for (final t in tracks) t.id: TrackMood.calm},
        TrackMood.calm,
        TrackMood.calm,
        const Duration(minutes: 10),
        random: Random(1),
      );
      final total = result.fold<int>(0, (sum, t) => sum + t.durationMs);
      expect((total - 600000).abs(), lessThanOrEqualTo(120000));
    },
  );
  test(
    'personal annotations survive a new store and malformed data stays intact',
    () async {
      await MoodPreferences().save({'x': TrackMood.energetic});
      expect(await MoodPreferences().load(), {'x': TrackMood.energetic});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(MoodPreferences.key, 'broken');
      await expectLater(MoodPreferences().load(), throwsFormatException);
      expect(prefs.getString(MoodPreferences.key), 'broken');
    },
  );
  testWidgets(
    'preview does not change playback; launch replaces queue with displayed order',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final player = QueuePlayer();
      final music = MusicController(audioPlayer: player)..ready = true;
      addTearDown(music.dispose);
      final tracks = List.generate(6, song);
      music.catalog.addAll(tracks);
      await MoodPreferences().save({
        for (var i = 0; i < 6; i++) '$i': TrackMood.values[i % 3],
      });
      await music.playCollection([tracks.last]);
      await tester.pumpWidget(
        MaterialApp(home: MoodJourneyScreen(music: music)),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Собрать подборку'));
      await tester.tap(find.text('Собрать подборку'));
      await tester.pumpAndSettle();
      expect(music.queue.map((t) => t.id), ['5']);
      await tester.scrollUntilVisible(
        find.text('Слушать по порядку'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Слушать по порядку'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(music.queue.length, 6);
      expect(music.queue.first.id, anyOf('0', '3'));
      expect(music.queue.last.id, anyOf('2', '5'));
      expect(tester.takeException(), isNull);
    },
  );
}
