import 'dart:convert';
import '../models/track.dart';

class PlaybackResume {
  PlaybackResume(
    this.tracks,
    this.index,
    this.position,
    this.shuffle,
    this.repeat,
  );
  final List<Track> tracks;
  final int index;
  final Duration position;
  final bool shuffle;
  final String repeat;
  static PlaybackResume? decode(String? raw, List<Track> catalog) {
    try {
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final byId = {for (final t in catalog) t.id: t};
      final ids = (data['queue'] as List).cast<String>().toSet();
      final tracks = [
        for (final id in ids)
          if (byId[id] != null) byId[id]!,
      ];
      if (tracks.isEmpty) return null;
      final selected = tracks.indexWhere((t) => t.id == data['track']);
      final index = selected < 0 ? 0 : selected;
      final ms = selected < 0 ? 0 : (data['positionMs'] as int);
      final duration = tracks[index].durationMs;
      return PlaybackResume(
        tracks,
        index,
        Duration(milliseconds: ms.clamp(0, duration > 0 ? duration : 86400000)),
        data['shuffle'] == true,
        data['repeat'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}
