import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/controllers/music_controller.dart';
import 'package:spun_music/ui/player_controls.dart';
import 'support/queue_player.dart';

class SeekPlayer extends QueuePlayer {
  @override
  bool get playing => true;
  final progress = StreamController<Duration>.broadcast(sync: true);
  Duration elapsed = Duration.zero;
  @override
  Stream<Duration> get positionStream => progress.stream;
  @override
  Duration get position => elapsed;
  void tick(Duration value) {
    elapsed = value;
    progress.add(value);
  }

  @override
  Future<void> dispose() async {
    await progress.close();
    await super.dispose();
  }

  final requests = <Duration?>[];
  final completeSeek = Completer<void>();
  @override
  Future<void> seek(Duration? position, {int? index}) async {
    requests.add(position);
    await completeSeek.future;
  }
}

void main() {
  testWidgets(
    'playback progress updates controls without rebuilding the library',
    (tester) async {
      final player = SeekPlayer();
      final music = MusicController(audioPlayer: player)..ready = true;
      addTearDown(music.dispose);
      var generalUpdates = 0;
      music.addListener(() => generalUpdates++);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PlayerControls(music: music)),
        ),
      );
      player.tick(const Duration(seconds: 42));
      await tester.pump();
      expect(tester.widget<Slider>(find.byType(Slider)).value, 42);
      expect(generalUpdates, 0);
    },
  );

  testWidgets(
    'scrubbing previews immediately and sends only one seek on release',
    (tester) async {
      final player = SeekPlayer();
      final music = MusicController(audioPlayer: player)..ready = true;
      addTearDown(music.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PlayerControls(music: music)),
        ),
      );
      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChangeStart!(10);
      for (final value in [20.0, 40.0, 65.0]) {
        slider.onChanged!(value);
      }
      await tester.pump();
      expect(tester.widget<Slider>(find.byType(Slider)).value, 65);
      expect(player.requests, isEmpty);
      slider.onChangeEnd!(65);
      await tester.pump();
      expect(player.requests, [const Duration(seconds: 65)]);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 65);
      player.completeSeek.complete();
      await tester.pump();
    },
  );
}
