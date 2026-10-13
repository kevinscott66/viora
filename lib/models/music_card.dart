import 'dart:convert';
import '../services/moment_link.dart';

class MusicCard {
  const MusicCard({
    required this.name,
    required this.lyric,
    required this.theme,
    required this.tracks,
  });
  final String name, lyric, theme;
  final List<ReceivedMoment> tracks;
  Map<String, dynamic> toJson() => {
    'v': 1,
    'name': name,
    'lyric': lyric,
    'theme': theme,
    'tracks': tracks.map((t) => t.summary).toList(),
  };
  factory MusicCard.fromJson(Map<String, dynamic> data) {
    final name = data['name'], lyric = data['lyric'], theme = data['theme'];
    if (data['v'] != 1 ||
        name is! String ||
        name.trim().isEmpty ||
        name.length > 50 ||
        lyric is! String ||
        lyric.length > 150 ||
        !['rose', 'ocean', 'violet'].contains(theme) ||
        data['tracks'] is! List ||
        (data['tracks'] as List).length != 3) {
      throw const FormatException('Invalid music card');
    }
    final tracks = <ReceivedMoment>[];
    for (final row in data['tracks']) {
      if (row is! Map<String, dynamic>) {
        throw const FormatException('Invalid track');
      }
      // Reuse strict moment validation without carrying a conversation or note.
      final track = ReceivedMoment.parse(
        Uri(scheme: 'viora', host: 'moment', fragment: jsonEncode(row)),
      );
      if (track == null || track.artists.isEmpty) {
        throw const FormatException('Invalid track');
      }
      tracks.add(ReceivedMoment(track.title, track.artists, track.seconds, ''));
    }
    if (tracks
            .map(
              (t) =>
                  '${t.title.trim().toLowerCase()}|${t.artists.join('|').toLowerCase()}',
            )
            .toSet()
            .length !=
        3) {
      throw const FormatException('Duplicate tracks');
    }
    return MusicCard(
      name: name.trim(),
      lyric: lyric,
      theme: theme,
      tracks: tracks,
    );
  }
}
