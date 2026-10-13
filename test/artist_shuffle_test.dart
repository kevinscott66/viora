import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/controllers/music_controller.dart';
import 'package:spun_music/models/track.dart';
import 'support/queue_player.dart';

class LastRandom implements Random {
  @override
  int nextInt(int max) => max - 1;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class AnchoredPlayer extends QueuePlayer {
  int count = 0;
  List<int> order = [];
  @override
  Future<Duration?> setAudioSources(
    sources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    shuffleOrder,
  }) async {
    count = sources.length;
    cursor = initialIndex ?? 0;
    order = List.generate(count, (i) => i);
    return null;
  }

  @override
  List<int> get effectiveIndices =>
      enabled ? order : List.generate(count, (i) => i);
  @override
  Future<void> shuffle() async {
    order = [
      cursor,
      ...List.generate(count, (i) => i).where((i) => i != cursor),
    ];
  }
}

void main() {
  test(
    'artist shuffle randomizes first track and keeps artist queue',
    () async {
      final player = AnchoredPlayer();
      final music = MusicController(audioPlayer: player, random: LastRandom())
        ..ready = true;
      addTearDown(music.dispose);
      final tracks = List.generate(
        3,
        (i) => Track(
          '$i',
          'Song $i',
          'Artist',
          Colors.red,
          localUri: 'file:///$i.mp3',
        ),
      );
      final other = Track(
        'other',
        'Other',
        'Other',
        Colors.blue,
        localUri: 'file:///other.mp3',
      );
      music.catalog.addAll([...tracks, other]);
      await music.playCollection([other]);
      await music.playCollection(tracks, shuffle: true);
      expect(player.cursor, 2);
      expect(music.shuffled, isTrue);
      expect(music.playbackQueue.map((t) => t.id), ['2', '0', '1']);
      await music.next();
      expect(player.cursor, 0);
      expect(music.queue.map((t) => t.id), ['0', '1', '2']);
      await music.playCollection([tracks.first], shuffle: true);
      expect(player.cursor, 0);
      await music.playCollection(tracks, startTrack: tracks[1]);
      expect(player.cursor, 1);
      expect(music.shuffled, isFalse);
    },
  );
}
