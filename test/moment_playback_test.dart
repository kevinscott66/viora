import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:spun_music/controllers/music_controller.dart';
import 'package:spun_music/models/track.dart';
import 'support/queue_player.dart';

class MomentPlayer extends QueuePlayer {
  Duration? loadedPosition;
  Duration? positionWhenPlayed;
  @override
  Future<Duration?> setAudioSources(
    List<AudioSource> sources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    ShuffleOrder? shuffleOrder,
  }) async {
    loadedPosition = initialPosition;
    return super.setAudioSources(
      sources,
      initialIndex: initialIndex,
      initialPosition: initialPosition,
    );
  }

  @override
  Future<void> play() async {
    positionWhenPlayed = loadedPosition;
  }
}

void main() {
  test(
    'moment loads timestamp before play and scopes queue to shared song',
    () async {
      final player = MomentPlayer();
      final music = MusicController(audioPlayer: player)..ready = true;
      addTearDown(music.dispose);
      const track = Track(
        'song',
        'Song',
        'Artist',
        Colors.red,
        localUri: 'file:///song.mp3',
        durationMs: 120000,
      );
      await music.playCollection([
        track,
      ], initialPosition: const Duration(seconds: 37));
      expect(player.positionWhenPlayed, const Duration(seconds: 37));
      expect(music.queue.map((t) => t.id), ['song']);
      await music.playCollection([
        track,
      ], initialPosition: const Duration(seconds: 500));
      expect(player.positionWhenPlayed, const Duration(seconds: 119));
    },
  );
}
