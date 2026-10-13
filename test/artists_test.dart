import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/models/artist.dart';
import 'package:spun_music/models/track.dart';
import 'package:spun_music/services/music_store_native.dart';
import 'package:spun_music/ui/artists.dart';

void main() {
  test('collaborations belong to both artists and case variants merge', () {
    final groups = groupArtists(
      [
        const Track(
          '1',
          'One',
          'Example artist 049',
          Colors.red,
          performers: ['Example artist 414', 'Example performer B'],
        ),
        const Track('2', 'Two', 'Example artist 414', Colors.red),
      ],
      {'Example artist 414': const ArtistInfo(name: 'Example artist 414', genre: 'Electronic')},
    );
    expect(groups.length, 2);
    expect(groups.first.info.name, 'Example artist 414');
    expect(groups.first.tracks.length, 2);
    expect(groups.last.tracks.single.id, '1');
    expect([1, 2, 5, 11, 21].map(trackCount), [
      '1 трек',
      '2 трека',
      '5 треков',
      '11 треков',
      '21 трек',
    ]);
  });
  test('artist images and verified credits restore relative paths', () async {
    final dir = await Directory.systemTemp.createTemp('spun_artist_');
    addTearDown(() => dir.delete(recursive: true));
    await File('${dir.path}/audio.mp3').writeAsBytes([1]);
    await File('${dir.path}/artists.json').writeAsString(
      jsonEncode([
        {'name': 'Example artist 414', 'image': 'portrait.jpg', 'genre': 'Electronic'},
      ]),
    );
    final store = MusicStore(directory: dir);
    await store.save([
      const Track(
        '1',
        'One',
        'Example artist 049',
        Colors.red,
        localUri: 'file:///audio.mp3',
        fileName: 'audio.mp3',
        performers: ['Example artist 414', 'Example performer B'],
        sourceUrl: 'https://music.apple.com/us/song/1',
      ),
    ]);
    final restored = (await store.load()).single;
    expect(restored.artistNames, ['Example artist 414', 'Example performer B']);
    expect(restored.sourceUrl, 'https://music.apple.com/us/song/1');
    expect(
      (await store.loadArtists())['Example artist 414']!.imagePath,
      '${dir.path}/portrait.jpg',
    );
  });
  testWidgets('artist card supports large text and taps on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var tapped = false;
    final a = ArtistCollection(
      const ArtistInfo(name: 'Очень длинное имя музыканта'),
      [const Track('1', 'Трек', 'Артист', Colors.red)],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 170,
                height: 240,
                child: ArtistTile(a, onTap: () => tapped = true),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.album_rounded), findsNothing);
    await tester.tap(find.byType(ArtistTile));
    expect(tapped, isTrue);
  });
}
