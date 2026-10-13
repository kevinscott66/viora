import 'package:flutter/material.dart';
import 'artist_credit.dart';

@immutable
class Track {
  const Track(
    this.id,
    this.title,
    this.artist,
    this.color, {
    this.localUri,
    this.fileName,
    this.artworkPath,
    this.artworkFile,
    this.album = '',
    this.durationMs = 0,
    this.performers = const [],
    this.sourceUrl,
  });
  final String id, title, artist, album;
  final Color color;
  final String? localUri, fileName, artworkPath, artworkFile;
  final int durationMs;
  final List<String> performers;
  final String? sourceUrl;
  List<String> get artistNames => artistCredits(artist, performers);
  bool get imported => localUri != null;
}

const emptyTrack = Track(
  'empty',
  'Ваша музыка',
  'Добавьте треки из Файлов',
  Color(0xff8f304f),
);
List<Track> searchTracks(String query, Iterable<Track> source) {
  final q = query.trim().toLowerCase();
  return source
      .where(
        (t) => '${t.title} ${t.artist} ${t.artistNames.join(' ')} ${t.album}'
            .toLowerCase()
            .contains(q),
      )
      .toList();
}

String formatTime(Duration value) =>
    '${value.inMinutes.toString().padLeft(2, '0')}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
String titleFromFile(String file) =>
    file.replaceFirst(RegExp(r'\.[^.]+$'), '').replaceAll('_', ' ');

String normalizeTrackText(String text) => text
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'[^a-zа-я0-9]'), '');
bool sameRecording(Track a, Track b) =>
    a.id == b.id ||
    (a.artist != 'Неизвестный исполнитель' &&
        normalizeTrackText(a.artist) == normalizeTrackText(b.artist) &&
        normalizeTrackText(a.title) == normalizeTrackText(b.title) &&
        a.durationMs > 0 &&
        b.durationMs > 0 &&
        (a.durationMs - b.durationMs).abs() < 1500);
