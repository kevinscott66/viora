import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track.dart';
import '../models/lyrics.dart';

Future<TrackLyrics> loadLyrics(Track track) async {
  if (!const bool.fromEnvironment('SPUN_PREVIEW') ||
      !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(track.id)) {
    return const TrackLyrics([]);
  }
  try {
    final r = await http.get(
      Uri.base.resolve('preview/${track.id}.lyrics.json'),
    );
    if (r.statusCode != 200 || r.bodyBytes.length > 2000000) {
      return const TrackLyrics([]);
    }
    return TrackLyrics.decode(jsonDecode(utf8.decode(r.bodyBytes)));
  } catch (_) {
    return const TrackLyrics([]);
  }
}
