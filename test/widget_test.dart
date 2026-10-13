import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/models/track.dart';
import 'package:spun_music/services/music_store_native.dart';
import 'package:spun_music/ui/shared.dart';

const tracks = [
  Track('thinking', 'Thinkin Bout You', 'Frank Ocean', Colors.blue),
  Track('provider', 'Provider', 'Frank Ocean', Colors.blue),
  Track('control', 'Lose Control', 'Teddy Swims', Colors.red),
];
void main() {
  test('search finds artists and titles regardless of case and whitespace', () {
    expect(searchTracks('  FRANK ocean ', tracks).length, 2);
    expect(searchTracks('control', tracks).single.id, 'control');
    expect(searchTracks('missing track', tracks), isEmpty);
  });
  test('import names preserve dotted titles and strip only extension', () {
    expect(titleFromFile('Artist - Part.2_song.MP3'), 'Artist - Part.2 song');
    expect(formatTime(const Duration(seconds: 185)), '03:05');
  });
  test(
    'native library restores relative paths and deletes only app copy',
    () async {
      final directory = await Directory.systemTemp.createTemp('spun_test_');
      addTearDown(() => directory.delete(recursive: true));
      final store = MusicStore(directory: directory);
      final source = File('${directory.path}/original.mp3');
      await source.writeAsBytes([1, 2, 3]);
      final copied = File('${directory.path}/local_1.mp3');
      await copied.writeAsBytes([1, 2, 3]);
      final track = Track(
        'local_1',
        'My Song',
        'Моя музыка',
        const Color(0xff53528e),
        localUri: copied.uri.toString(),
        fileName: 'local_1.mp3',
      );
      await store.save([track]);
      final restored = (await store.load()).single;
      expect(restored.title, 'My Song');
      expect(restored.localUri, copied.uri.toString());
      await store.save([]);
      await store.delete(restored);
      expect(await source.exists(), isTrue);
      expect(await copied.exists(), isFalse);
      expect(await store.load(), isEmpty);
    },
  );
  test('missing imported files do not break restoring library', () async {
    final directory = await Directory.systemTemp.createTemp('spun_test_');
    addTearDown(() => directory.delete(recursive: true));
    final store = MusicStore(directory: directory);
    await store.save([
      const Track(
        'gone',
        'Gone',
        'Me',
        Colors.blue,
        localUri: 'file:///gone.mp3',
        fileName: 'gone.mp3',
      ),
    ]);
    expect(await store.load(), isEmpty);
  });
  test('dedup ignores typography but preserves different recordings', () {
    const a = Track('a', 'Моя песня', 'Артист', Colors.red, durationMs: 180000);
    const b = Track(
      'b',
      'Моя песня!',
      'АРТИСТ',
      Colors.red,
      durationMs: 180400,
    );
    const remix = Track(
      'c',
      'Моя песня (Remix)',
      'Артист',
      Colors.red,
      durationMs: 180000,
    );
    expect(sameRecording(a, b), isTrue);
    expect(sameRecording(a, remix), isFalse);
  });
  test('metadata and artwork round trip without hardcoded artist', () async {
    final directory = await Directory.systemTemp.createTemp('spun_metadata_');
    addTearDown(() => directory.delete(recursive: true));
    await File('${directory.path}/song.mp3').writeAsBytes([1, 2, 3]);
    final store = MusicStore(directory: directory);
    await store.save([
      const Track(
        'song',
        'Песня',
        'Исполнитель',
        Colors.blue,
        localUri: 'file:///song.mp3',
        fileName: 'song.mp3',
        album: 'Альбом',
        durationMs: 210000,
        artworkFile: 'cover.jpg',
      ),
    ]);
    final restored = (await store.load()).single;
    expect(restored.artist, 'Исполнитель');
    expect(restored.album, 'Альбом');
    expect(restored.durationMs, 210000);
    expect(restored.artworkPath, '${directory.path}/cover.jpg');
    expect(searchTracks('альбом', [restored]), [restored]);
  });
  testWidgets('custom cover scales on phone with large text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SizedBox(
              width: 48,
              height: 48,
              child: Cover(
                Track(
                  'local',
                  'My track',
                  'Me',
                  Colors.blue,
                  localUri: 'file:///audio.mp3',
                ),
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.album_rounded), findsOneWidget);
  });
}
