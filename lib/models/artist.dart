import 'track.dart';
import 'artist_credit.dart';

class ArtistInfo {
  const ArtistInfo({
    required this.name,
    this.imagePath,
    this.genre = '',
    this.sourceUrl,
    this.imageAlignmentY = -1,
  });
  final String name, genre;
  final double imageAlignmentY;
  final String? imagePath, sourceUrl;
}

class ArtistCollection {
  const ArtistCollection(this.info, this.tracks);
  final ArtistInfo info;
  final List<Track> tracks;
  Track get cover => tracks.firstWhere(
    (t) => t.artworkPath != null,
    orElse: () => tracks.first,
  );
  Duration get duration =>
      Duration(milliseconds: tracks.fold(0, (sum, t) => sum + t.durationMs));
}

/// One directory serves discovery, search and credits in the player.
class ArtistDirectory {
  ArtistDirectory(Iterable<Track> tracks, Map<String, ArtistInfo> info) {
    final profiles = {
      for (final value in info.values) artistKey(value.name): value,
    };
    final groups = <String, Map<String, Track>>{};
    final names = <String, String>{};
    for (final track in tracks) {
      for (final name in track.artistNames) {
        final key = artistKey(name);
        names.putIfAbsent(key, () => name);
        (groups[key] ??= {})[track.id] = track;
      }
    }
    _byKey = Map.unmodifiable({
      for (final entry in groups.entries)
        entry.key: ArtistCollection(
          profiles[entry.key] ?? ArtistInfo(name: names[entry.key]!),
          List.unmodifiable(entry.value.values),
        ),
    });
    final sorted = _byKey.values.toList()
      ..sort((a, b) {
        final count = b.tracks.length.compareTo(a.tracks.length);
        return count != 0 ? count : a.info.name.compareTo(b.info.name);
      });
    artists = List.unmodifiable(sorted);
  }
  late final Map<String, ArtistCollection> _byKey;
  late final List<ArtistCollection> artists;
  ArtistCollection? find(String name) => _byKey[artistKey(name)];
  List<ArtistCollection> forTrack(Track track) => [
    for (final name in track.artistNames) ?find(name),
  ];
}

List<ArtistCollection> groupArtists(
  Iterable<Track> tracks,
  Map<String, ArtistInfo> info,
) => ArtistDirectory(tracks, info).artists;

String trackCount(int count) {
  final n = count % 100;
  final word = n >= 11 && n <= 14
      ? 'треков'
      : switch (count % 10) {
          1 => 'трек',
          2 || 3 || 4 => 'трека',
          _ => 'треков',
        };
  return '$count $word';
}
