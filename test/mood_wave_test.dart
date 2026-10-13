import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spun_music/controllers/music_controller.dart';
import 'package:spun_music/models/track.dart';
import 'package:spun_music/services/mood_journey.dart';
import 'package:spun_music/ui/mood_wave.dart';
import 'support/queue_player.dart';
import 'package:spun_music/services/wave_stations.dart';

class WavePlayer extends QueuePlayer {
  LoopMode mode = LoopMode.off;
  @override
  LoopMode get loopMode => mode;
  @override
  Future<void> setLoopMode(LoopMode m) async {
    mode = m;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'synthetic station labels override numerical moods and deduplicate',
    () async {
      final stations = await WaveStations.load();
      final evidence = await MoodEvidence.load();
      Track recording(int n) => Track(
        'fixture_$n',
        'Example recording $n',
        'Example artist',
        Colors.pink,
        localUri: 'file:///$n.mp3',
      );
      final all = [recording(1), recording(2), recording(3), recording(1)];
      expect(stations.select(all, 'party').map((t) => t.id), [
        'fixture_1',
        'fixture_3',
      ]);
      expect(stations.select(all, 'sad').map((t) => t.id), ['fixture_2']);
      expect(stations.select(all, 'rebel'), isEmpty);
      expect(stations.tracks.keys.toSet(), evidence.tracks.keys.toSet());
      expect(evidence.tone('fixture_3'), TrackTone.melancholic);
    },
  );
  test(
    'internet seed only includes supported songs and preserves manual labels',
    () async {
      final seed =
          jsonDecode(await rootBundle.loadString('assets/mood_seed.json'))
              as Map<String, dynamic>;
      final evidence = await MoodEvidence.load();
      expect(evidence.tracks.length, 7);
      expect(seed.isNotEmpty, true);
      expect(seed.keys.every(evidence.verified), true);
      final id = seed.keys.first;
      SharedPreferences.setMockInitialValues({
        'moodJourney': jsonEncode({
          'version': 1,
          'labels': {id: 'calm'},
        }),
      });
      final prefs = MoodPreferences();
      final loaded = await prefs.load();
      expect(loaded.length, seed.length);
      expect(loaded[id], TrackMood.calm);
      loaded.remove(id);
      await prefs.save(loaded);
      expect((await MoodPreferences().load()).containsKey(id), false);
    },
  );
  test(
    'migration removes old guesses, backs up all old data, and retains distinct edits',
    () async {
      final old =
          jsonDecode(
                await rootBundle.loadString('assets/mood_seed_audio_v1.json'),
              )
              as Map<String, dynamic>;
      final seed =
          jsonDecode(await rootBundle.loadString('assets/mood_seed.json'))
              as Map<String, dynamic>;
      final unknown = old.keys.firstWhere((id) => !seed.containsKey(id));
      final edited = old.keys.firstWhere((id) => id != unknown);
      final manual = TrackMood.values.firstWhere((m) => m.name != old[edited]);
      final raw = jsonEncode({
        'version': 1,
        'seed': 'audio-2026-10-10',
        'labels': {...old, edited: manual.name},
      });
      SharedPreferences.setMockInitialValues({'moodJourney': raw});
      final loaded = await MoodPreferences().load();
      expect(loaded.containsKey(unknown), false);
      expect(loaded[edited], manual);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'moodJourneyBeforeInternet',
        ),
        raw,
      );
      expect(await MoodPreferences().load(), loaded);
      final evidence = await MoodEvidence.load();
      expect(evidence.tone(unknown), isNull);
    },
  );
  testWidgets('home mood card starts the filtered shuffled queue directly', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final seed = (await tester.runAsync(() async {
      await MoodPreferences().load();
      await MoodEvidence.load();
      await WaveStations.load();
      return (await WaveStations.load()).tracks;
    }))!;
    final ids = seed.keys
        .where((id) => (seed[id]['stations'] as List).contains('groove'))
        .take(2)
        .toList();
    final player = WavePlayer();
    final music = MusicController(audioPlayer: player)..ready = true;
    addTearDown(music.dispose);
    music.catalog.addAll([
      for (var i = 0; i < ids.length; i++)
        Track(
          ids[i],
          'Track $i',
          'Artist',
          Colors.pink,
          localUri: 'file:///$i.mp3',
          durationMs: 90000,
        ),
      const Track(
        'unknown',
        'Unknown',
        'Artist',
        Colors.blue,
        localUri: 'file:///unknown.mp3',
        durationMs: 90000,
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(body: HomeMoodWaves(music: music)),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Наваливай'));
    await tester.pumpAndSettle();
    expect(music.queue.map((t) => t.id).toSet(), ids.toSet());
    expect(player.shuffleModeEnabled, true);
    expect(player.loopMode, LoopMode.all);
    expect(music.activeWavePreset, 'home-v2:groove');
    await tester.tap(
      find.byTooltip('Убрать настроение и включить общую волну'),
    );
    await tester.pumpAndSettle();
    expect(music.queue.length, 3);
    expect(music.activeWavePreset, 'home-v2:all');
    await music.playCollection([music.catalog.first]);
    await tester.pumpAndSettle();
    expect(music.activeWavePreset, isNull);
    expect(find.byType(HomeMoodWaves), findsOneWidget);
    expect(find.byType(MoodWave), findsNothing);
    expect(find.text('Моя волна'), findsNothing);
    expect(find.text('Выдохнуть'), findsNothing);
    expect(find.text('Поймать позитив'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test(
    'wave filters moods without duplicates and restores loop setting on normal collection',
    () async {
      final tracks = List.generate(
        3,
        (i) => Track(
          '$i',
          'Song $i',
          'Artist',
          Colors.blue,
          localUri: 'file:///$i.mp3',
          durationMs: 90000,
        ),
      );
      expect(
        moodWaveTracks(
          [...tracks, tracks.first],
          {'0': TrackMood.calm, '1': TrackMood.energetic},
          TrackMood.calm,
        ).map((t) => t.id),
        ['0'],
      );
      expect(moodWaveTracks([...tracks, tracks.first], {}, null).length, 3);
      final evidence = MoodEvidence({
        '0': {'status': 'verified', 'tone': 'melancholic'},
        '1': {'status': 'verified', 'tone': 'bright'},
        '2': {'status': 'conflict', 'tone': 'bright'},
      });
      expect(
        moodWaveTracks(
          tracks,
          {},
          null,
          tone: TrackTone.bright,
          evidence: evidence,
        ).map((t) => t.id),
        ['1'],
      );
      expect(
        moodWaveTracks(
          tracks,
          {'0': TrackMood.energetic},
          TrackMood.energetic,
          tone: TrackTone.melancholic,
          evidence: evidence,
        ).map((t) => t.id),
        ['0'],
      );
      expect(
        moodWaveTracks(tracks, {}, null, tone: TrackTone.bright).isEmpty,
        true,
      );

      final player = WavePlayer();
      final music = MusicController(audioPlayer: player, random: Random(42))
        ..ready = true;
      music.catalog.addAll(tracks);
      await music.playCollection(tracks, shuffle: true, repeatQueue: true);
      expect(music.error, isNull);
      expect(player.shuffleModeEnabled, true);
      expect(player.loopMode, LoopMode.all);
      await music.playCollection(tracks);
      expect(player.shuffleModeEnabled, false);
      expect(player.loopMode, LoopMode.off);
      music.dispose();
    },
  );
}
