import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/models/track.dart';
import 'package:spun_music/services/library_codec.dart';

void main() {
  final native = LibraryCodec(
    audioUri: (n) => Uri.file('/Music/$n').toString(),
    imagePath: (n) => '/Music/$n',
  );
  final web = LibraryCodec(
    audioUri: (n) =>
        Uri.parse('http://localhost/preview/').resolve(n).toString(),
    imagePath: (n) => 'http://localhost/preview/$n',
  );
  test('same schema preserves metadata across native and preview paths', () {
    const track = Track(
      'id',
      'Название',
      'A, B',
      Colors.red,
      localUri: 'file:///old/song.mp3',
      fileName: 'song.mp3',
      artworkFile: 'cover.jpg',
      album: 'Album',
      durationMs: 123000,
      performers: ['A', 'B'],
      sourceUrl: 'https://example.com/release',
    );
    final row = LibraryCodec.encodeTrack(track);
    final phone = native.decodeTrack(row)!;
    final browser = web.decodeTrack(row)!;
    expect(LibraryCodec.encodeTrack(phone), row);
    expect(LibraryCodec.encodeTrack(browser), row);
    expect(phone.localUri, 'file:///Music/song.mp3');
    expect(browser.localUri, 'http://localhost/preview/song.mp3');
    expect(phone.artworkPath, '/Music/cover.jpg');
    expect(browser.artworkPath, 'http://localhost/preview/cover.jpg');
  });
  test(
    'legacy metadata defaults and invalid relative filenames remain supported',
    () {
      final row = <String, dynamic>{
        'id': 'old',
        'title': 'Song',
        'color': 0xff000000,
        'file': 'old.mp3',
      };
      final track = native.decodeTrack(row)!;
      expect(track.artist, 'Неизвестный исполнитель');
      expect(track.performers, isEmpty);
      expect(track.durationMs, 0);
      expect(track.artworkPath, isNull);
      expect(native.decodeTrack({...row, 'file': '../outside.mp3'}), isNull);
      expect(
        web.decodeTrack({...row, 'file': 'https://external/song.mp3'}),
        isNull,
      );
      expect(
        native.decodeTrack({...row, 'artwork': '../cover.jpg'})!.artworkPath,
        isNull,
      );
    },
  );
  test('artist portraits share metadata without platform-specific JSON', () {
    final row = <String, dynamic>{
      'name': 'Artist',
      'image': 'artist.jpg',
      'genre': 'Rock',
      'sourceUrl': 'https://example.com/artist',
    };
    final phone = native.decodeArtist(row), browser = web.decodeArtist(row);
    expect(phone.name, browser.name);
    expect(phone.genre, browser.genre);
    expect(phone.sourceUrl, browser.sourceUrl);
    expect(phone.imagePath, '/Music/artist.jpg');
    expect(browser.imagePath, 'http://localhost/preview/artist.jpg');
  });
}
