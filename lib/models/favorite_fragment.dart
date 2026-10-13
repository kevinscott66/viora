import 'track.dart';

/// A private bookmark; audio remains in the music library.
class FavoriteFragment {
  const FavoriteFragment({
    required this.id,
    required this.trackId,
    required this.title,
    required this.artist,
    required this.startMs,
    required this.endMs,
    this.collection = '',
    this.note = '',
  });
  final String id, trackId, title, artist, collection, note;
  final int startMs, endMs;
  Map<String, dynamic> toJson() => {
    'version': 1,
    'id': id,
    'trackId': trackId,
    'title': title,
    'artist': artist,
    'startMs': startMs,
    'endMs': endMs,
    'collection': collection,
    'note': note,
  };
  factory FavoriteFragment.fromJson(Map<String, dynamic> json) {
    final f = FavoriteFragment(
      id: json['id'],
      trackId: json['trackId'],
      title: json['title'],
      artist: json['artist'],
      startMs: json['startMs'],
      endMs: json['endMs'],
      collection: json['collection'] ?? '',
      note: json['note'] ?? '',
    );
    if (json['version'] != 1 ||
        !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(f.id) ||
        f.trackId.isEmpty ||
        f.startMs < 0 ||
        f.endMs <= f.startMs ||
        f.endMs > 86400000 ||
        f.collection.length > 60 ||
        f.note.length > 300) {
      throw const FormatException('Invalid favorite fragment');
    }
    return f;
  }
  bool fits(Track track) =>
      track.id == trackId && track.imported && track.durationMs >= endMs;
}
