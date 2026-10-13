import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/controllers/music_controller.dart';
import 'package:spun_music/models/track.dart';

import 'support/queue_player.dart';

void main() {
  late QueuePlayer player;
  late MusicController music;
  setUp(() {
    player = QueuePlayer();
    music = MusicController(audioPlayer: player)..ready = true;
    final tracks = List.generate(
      3,
      (i) => Track(
        '$i',
        'Track $i',
        'Artist',
        Colors.red,
        localUri: 'file:///$i.mp3',
      ),
    );
    music.catalog.addAll(tracks);
    music.queue.addAll(tracks);
  });
  tearDown(() => music.dispose());

  test('stale queue selection never expands into the full catalog', () async {
    final outside = Track(
      'outside',
      'Outside',
      'Other',
      Colors.blue,
      localUri: 'file:///outside.mp3',
    );
    music.catalog.add(outside);
    await music.select(outside);
    expect(music.queue.map((t) => t.id), ['0', '1', '2']);
    expect(player.cursor, 0);
  });
  test(
    'collection snapshots caller list before asynchronous loading',
    () async {
      final selection = List<Track>.of(music.catalog);
      final pending = music.playCollection(selection, startTrack: selection[1]);
      selection.clear();
      await pending;
      expect(music.queue.map((t) => t.id), ['0', '1', '2']);
      expect(player.cursor, 1);
    },
  );
  test(
    'shuffle display follows actual order and disabling restores source order',
    () async {
      await music.toggleShuffle();
      expect(music.playbackQueue.map((t) => t.id), ['2', '0', '1']);
      expect(music.queue.map((t) => t.id), ['0', '1', '2']);
      expect(player.cursor, 0); // Toggling keeps the playing track.
      await music.select(music.playbackQueue.first);
      expect(player.cursor, 2); // A visible row seeks its source index.
      await music.next();
      expect(player.cursor, 0);
      await music.toggleShuffle();
      expect(music.playbackQueue.map((t) => t.id), ['0', '1', '2']);
    },
  );
  test('next and previous wrap in shuffled order', () async {
    await music.toggleShuffle();
    player.cursor = 1;
    await music.next();
    expect(player.cursor, 2);
    await music.previous();
    expect(player.cursor, 1);
  });
  test(
    'artist shuffle uses same mode and can restore original order',
    () async {
      await music.playCollection(List.of(music.catalog), shuffle: true);
      expect(music.shuffled, isTrue);
      expect(player.cursor, 2);
      expect(music.playbackQueue.first.id, '2');
      await music.toggleShuffle();
      expect(music.playbackQueue.map((t) => t.id), ['0', '1', '2']);
      await music.playCollection(List.of(music.catalog));
      expect(music.shuffled, isFalse);
      expect(player.cursor, 0);
    },
  );
}
