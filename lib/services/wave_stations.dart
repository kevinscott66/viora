import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/track.dart';

/// User-approved station membership is authoritative per recording.
/// Numerical audio estimates must never override the imported table.
class WaveStations {
  WaveStations(this.tracks);
  final Map<String, dynamic> tracks;

  static Future<WaveStations> load() async {
    final data =
        jsonDecode(await rootBundle.loadString('assets/wave_stations.json'))
            as Map<String, dynamic>;
    return WaveStations(data['tracks'] as Map<String, dynamic>);
  }

  bool contains(String id, String station) =>
      (tracks[id]?['stations'] as List<dynamic>?)?.contains(station) ?? false;

  List<Track> select(Iterable<Track> catalog, String station) {
    final result = <Track>[];
    for (final track in catalog) {
      final matches = contains(track.id, station);
      if (track.imported &&
          matches &&
          !result.any((other) => sameRecording(other, track))) {
        result.add(track);
      }
    }
    return result;
  }
}
