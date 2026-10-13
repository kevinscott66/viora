import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';

enum TrackMood {
  calm('Спокойно'),
  steady('Ровно'),
  energetic('Энергично');

  const TrackMood(this.label);
  final String label;
}

/// Uses saved labels; imported songs without a label are excluded.
List<Track> buildMoodJourney(
  List<Track> source,
  Map<String, TrackMood> labels,
  TrackMood start,
  TrackMood end,
  Duration duration, {
  Random? random,
}) {
  final pool = <Track>[];
  for (final t in source) {
    if (t.imported &&
        t.durationMs > 0 &&
        labels.containsKey(t.id) &&
        labels[t.id]!.index >= min(start.index, end.index) &&
        labels[t.id]!.index <= max(start.index, end.index) &&
        !pool.any((other) => sameRecording(t, other))) {
      pool.add(t);
    }
  }
  pool.shuffle(random ?? Random());
  final result = <Track>[];
  var elapsed = 0;
  final target = duration.inMilliseconds;
  if (target <= 0) return result;
  while (pool.isNotEmpty && elapsed < target) {
    final progress = (elapsed / target).clamp(0.0, 1.0);
    final wanted = start.index + (end.index - start.index) * progress;
    pool.sort((a, b) {
      double score(Track t) =>
          (labels[t.id]!.index - wanted).abs() +
          max(0, elapsed + t.durationMs - target) / target;
      return score(a).compareTo(score(b));
    });
    final fits = pool
        .where(
          (t) =>
              result.isEmpty ||
              (elapsed + t.durationMs - target).abs() <=
                  (elapsed - target).abs(),
        )
        .toList();
    if (fits.isEmpty) break;
    final next = fits.first;
    result.add(next);
    pool.remove(next);
    elapsed += next.durationMs;
  }
  // Keep an ordered gradual progression; ties retain generated variety.
  final order = {for (var i = 0; i < result.length; i++) result[i].id: i};
  result.sort((a, b) {
    final difference = labels[a.id]!.index.compareTo(labels[b.id]!.index);
    return difference == 0
        ? order[a.id]!.compareTo(order[b.id]!)
        : (start.index <= end.index ? difference : -difference);
  });
  return result;
}

class MoodPreferences {
  static const key = 'moodJourney';
  static const revision = 'internet-2026-10-10';
  Future<Map<String, TrackMood>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    final data = raw == null
        ? <String, dynamic>{'version': 1, 'labels': <String, dynamic>{}}
        : jsonDecode(raw) as Map<String, dynamic>;
    if (data['version'] != 1) {
      throw const FormatException('Unknown mood schema');
    }
    final labels = (data['labels'] as Map<String, dynamic>).map(
      (id, value) => MapEntry(id, TrackMood.values.byName(value as String)),
    );
    if (data['seed'] != revision) {
      // Keep a recoverable copy, including edits equal to the old automatic value.
      if (raw != null && !prefs.containsKey('moodJourneyBeforeInternet')) {
        if (!await prefs.setString('moodJourneyBeforeInternet', raw)) {
          throw StateError('Cannot back up mood labels');
        }
      }
      final seed =
          jsonDecode(await rootBundle.loadString('assets/mood_seed.json'))
              as Map<String, dynamic>;
      final oldSeed =
          jsonDecode(
                await rootBundle.loadString('assets/mood_seed_audio_v1.json'),
              )
              as Map<String, dynamic>;
      if (data['seed'] == 'audio-2026-10-10') {
        // v1 did not record provenance. Values differing from its seed are edits.
        labels.removeWhere((id, value) => oldSeed[id] == value.name);
      }
      for (final e in seed.entries) {
        labels.putIfAbsent(
          e.key,
          () => TrackMood.values.byName(e.value as String),
        );
      }
      await save(labels);
    }
    return labels;
  }

  Future<void> save(Map<String, TrackMood> labels) async {
    final success = await (await SharedPreferences.getInstance()).setString(
      key,
      jsonEncode({
        'version': 1,
        'seed': revision,
        'labels': labels.map((id, mood) => MapEntry(id, mood.name)),
      }),
    );
    if (!success) throw StateError('Cannot save mood labels');
  }
}

enum TrackTone {
  melancholic('Меланхолично'),
  balanced('Нейтрально'),
  bright('Светло');

  const TrackTone(this.label);
  final String label;
}

class MoodEvidence {
  MoodEvidence(this.tracks);
  final Map<String, dynamic> tracks;
  static Future<MoodEvidence> load() async {
    final data =
        jsonDecode(await rootBundle.loadString('assets/mood_evidence.json'))
            as Map<String, dynamic>;
    return MoodEvidence(data['tracks'] as Map<String, dynamic>);
  }

  bool verified(String id) => tracks[id]?['status'] == 'verified';
  TrackTone? tone(String id) {
    final value = tracks[id]?['tone'];
    return verified(id) && value != null
        ? TrackTone.values.byName(value as String)
        : null;
  }
}
