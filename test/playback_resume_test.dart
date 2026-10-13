import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/models/track.dart';
import 'package:spun_music/services/playback_resume.dart';

void main() {
  final tracks = List.generate(
    3,
    (i) => Track('$i', 'Song $i', 'Artist', Colors.red, durationMs: 120000),
  );
  String state(String id, int ms) => jsonEncode({
    'queue': ['2', 'gone', '1'],
    'track': id,
    'positionMs': ms,
    'shuffle': true,
    'repeat': 'all',
  });
  test(
    'restores selected track position and scoped queue, skipping missing files',
    () {
      final r = PlaybackResume.decode(state('1', 45000), tracks)!;
      expect(r.tracks.map((t) => t.id), ['2', '1']);
      expect(r.index, 1);
      expect(r.position.inSeconds, 45);
      expect(r.shuffle, isTrue);
    },
  );
  test('missing selected track starts remaining queue at zero', () {
    final r = PlaybackResume.decode(state('gone', 45000), tracks)!;
    expect(r.index, 0);
    expect(r.position, Duration.zero);
  });
  test('invalid data is ignored and seek position is bounded', () {
    expect(PlaybackResume.decode('{broken', tracks), isNull);
    expect(
      PlaybackResume.decode(state('1', 999999), tracks)!.position.inSeconds,
      120,
    );
    expect(
      PlaybackResume.decode(state('1', -4), tracks)!.position,
      Duration.zero,
    );
  });
}
