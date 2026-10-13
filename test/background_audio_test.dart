import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:spun_music/controllers/music_controller.dart';
import 'package:spun_music/models/track.dart';
import 'package:spun_music/services/background_audio.dart';
import 'support/queue_player.dart';

void main() {
  test(
    'system metadata preserves track identity and deduplicated collaborators',
    () {
      const track = Track(
        'unique-id',
        'Совместный трек',
        'A, B, b',
        Colors.red,
        localUri: 'file:///Music/song.mp3',
        album: 'Альбом',
        durationMs: 185000,
        performers: ['A', 'B', 'b'],
        artworkPath: '/Music/Моя обложка.jpg',
      );
      final music = MusicController(audioPlayer: QueuePlayer());
      addTearDown(music.dispose);
      final source = music.sourceFor(track) as UriAudioSource;
      final item = source.tag as MediaItem;
      expect(source.uri, Uri.parse(track.localUri!));
      expect(item.id, track.id);
      expect(item.title, track.title);
      expect(item.artist, 'A, B');
      expect(item.album, track.album);
      expect(item.duration, const Duration(seconds: 185));
      expect(item.artUri!.scheme, 'file');
      expect(item.artUri!.toFilePath(), track.artworkPath);
    },
  );
  test(
    'unknown duration and missing artwork do not invent system metadata',
    () {
      const track = Track('id', 'Song', 'Неизвестный исполнитель', Colors.red);
      final item = mediaItemFor(track);
      expect(item.duration, isNull);
      expect(item.artUri, isNull);
      expect(item.album, isNull);
      expect(item.artist, 'Неизвестный исполнитель');
    },
  );
  test('preview artwork URLs remain URLs', () {
    const track = Track(
      'id',
      'Song',
      'Artist',
      Colors.red,
      artworkPath: 'http://127.0.0.1:8793/preview/cover.jpg',
    );
    expect(mediaItemFor(track).artUri.toString(), track.artworkPath);
  });
}
