import 'dart:convert';
import 'dart:io';
import '../models/track.dart';
import '../models/lyrics.dart';
import 'music_store_native.dart';

Future<TrackLyrics> loadLyrics(Track track) async {
  if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(track.id)) {
    return const TrackLyrics([]);
  }
  try {
    final root = await MusicStore().root;
    final file = File('${root.path}/${track.id}.lyrics.json');
    if (!await file.exists() || await file.length() > 2000000) {
      return const TrackLyrics([]);
    }
    final data = jsonDecode(await file.readAsString());
    if (data is! Map || data['trackId'] != track.id) {
      return const TrackLyrics([]);
    }
    return TrackLyrics.decode(data);
  } catch (_) {
    return const TrackLyrics([]);
  }
}
