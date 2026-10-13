class LyricCue {
  const LyricCue(this.startMs, this.endMs, this.text);
  final int startMs, endMs;
  final String text;
}

class TrackLyrics {
  const TrackLyrics(this.cues, {this.automatic = true});
  final List<LyricCue> cues;
  final bool automatic;
  static TrackLyrics decode(dynamic data) {
    if (data is! Map || data['version'] != 1 || data['cues'] is! List) {
      return const TrackLyrics([]);
    }
    final cues = <LyricCue>[];
    for (final row in (data['cues'] as List).take(3000)) {
      if (row is! Map ||
          row['startMs'] is! int ||
          row['endMs'] is! int ||
          row['text'] is! String) {
        continue;
      }
      final start = row['startMs'] as int, end = row['endMs'] as int;
      final text = (row['text'] as String).trim();
      if (start < 0 ||
          end <= start ||
          end > 86400000 ||
          text.isEmpty ||
          text.length > 1000) {
        continue;
      }
      cues.add(LyricCue(start, end, text));
    }
    cues.sort((a, b) => a.startMs.compareTo(b.startMs));
    return TrackLyrics(
      cues,
      automatic:
          data['status'] != 'verified' && data['status'] != 'user_supplied',
    );
  }

  int indexAt(Duration position) => cues.lastIndexWhere(
    (c) =>
        position.inMilliseconds >= c.startMs &&
        position.inMilliseconds < c.endMs,
  );
}
