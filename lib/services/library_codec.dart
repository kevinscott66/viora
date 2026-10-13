import 'package:flutter/material.dart';
import '../models/artist.dart';
import '../models/track.dart';

/// Shared JSON schema. Storage adapters only resolve paths and perform I/O.
class LibraryCodec {
  const LibraryCodec({required this.audioUri, required this.imagePath});
  final String Function(String name) audioUri, imagePath;

  static String? safeName(dynamic value) =>
      value is String &&
          value.isNotEmpty &&
          !value.contains('/') &&
          !value.contains('..')
      ? value
      : null;

  Track? decodeTrack(Map<String, dynamic> row) {
    final name = safeName(row['file']);
    if (name == null) return null;
    final cover = safeName(row['artwork']);
    return Track(
      row['id'] as String,
      row['title'] as String,
      row['artist'] as String? ?? 'Неизвестный исполнитель',
      Color(row['color'] as int),
      localUri: audioUri(name),
      fileName: name,
      album: row['album'] as String? ?? '',
      performers:
          (row['performers'] as List<dynamic>?)?.cast<String>() ?? const [],
      sourceUrl: row['sourceUrl'] as String?,
      durationMs: row['durationMs'] as int? ?? 0,
      artworkFile: cover,
      artworkPath: cover == null ? null : imagePath(cover),
    );
  }

  ArtistInfo decodeArtist(Map<String, dynamic> row) {
    final image = safeName(row['image']);
    return ArtistInfo(
      name: row['name'] as String,
      genre: row['genre'] as String? ?? '',
      sourceUrl: row['sourceUrl'] as String?,
      imagePath: image == null ? null : imagePath(image),
      imageAlignmentY: (row['imageAlignmentY'] as num? ?? -1).toDouble().clamp(
        -1.0,
        1.0,
      ),
    );
  }

  static Map<String, dynamic> encodeTrack(Track t) => {
    'id': t.id,
    'title': t.title,
    'artist': t.artist,
    'album': t.album,
    'performers': t.performers,
    'sourceUrl': t.sourceUrl,
    'durationMs': t.durationMs,
    'file': t.fileName,
    'artwork': t.artworkFile,
    'color': t.color.toARGB32(),
  };
}
