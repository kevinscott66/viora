import 'lyrics.dart';

/// Keeps selection order and export limits independent of the lyrics UI.
class LyricSelection {
  static const maxLines = 3;
  static const maxLength = 150;
  final Set<int> _indices = {};
  int get length => _indices.length;
  bool get isEmpty => _indices.isEmpty;
  bool contains(int index) => _indices.contains(index);
  void clear() => _indices.clear();
  List<int> get ordered => _indices.toList()..sort();
  String text(TrackLyrics lyrics) =>
      ordered.map((i) => lyrics.cues[i].text).join('\n');
  Duration position(TrackLyrics lyrics) =>
      Duration(milliseconds: lyrics.cues[ordered.first].startMs);

  bool toggle(int index, TrackLyrics lyrics) {
    if (index < 0 || index >= lyrics.cues.length) return false;
    final next = {..._indices};
    if (!next.remove(index)) next.add(index);
    final sorted = next.toList()..sort();
    if (next.length > maxLines ||
        sorted.map((i) => lyrics.cues[i].text).join('\n').length > maxLength) {
      return false;
    }
    _indices
      ..clear()
      ..addAll(next);
    return true;
  }
}
