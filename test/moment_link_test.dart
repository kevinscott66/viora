import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/models/track.dart';
import 'package:spun_music/services/moment_link.dart';

void main() {
  test(
    'reply retains one parent and excludes its private note and older history',
    () {
      const older = ReceivedMoment('Older', ['Artist'], 1, 'secret');
      const parent = ReceivedMoment(
        'Parent',
        ['Artist'],
        20,
        'private note',
        lyric: 'Selected line',
        replyTo: older,
      );
      const track = Track('id', 'Answer', 'Other', Colors.red);
      final uri = momentLink(
        track,
        const Duration(seconds: 8),
        'Reply note',
        replyTo: parent,
      );
      final result = ReceivedMoment.parse(uri)!;
      expect(result.replyTo!.title, 'Parent');
      expect(result.replyTo!.lyric, 'Selected line');
      expect(result.replyTo!.note, isEmpty);
      expect(result.replyTo!.replyTo, isNull);
      expect(uri.toString(), isNot(contains('private')));
      final payload = {
        'v': 1,
        'title': 'Answer',
        'artists': ['A'],
        'seconds': 0,
        'note': '',
        'replyTo': {...parent.summary, 'replyTo': older.summary},
      };
      expect(
        ReceivedMoment.parse(
          Uri(scheme: 'viora', host: 'moment', fragment: jsonEncode(payload)),
        ),
        isNull,
      );
    },
  );

  test('moment uses fragment and excludes private file locations', () {
    const track = Track(
      'private-id',
      'Песня & #',
      'Артист',
      Colors.red,
      localUri: '/private/audio.mp3',
      artworkPath: '/private/cover.png',
    );
    final link = momentLink(track, const Duration(seconds: 37), ' Для тебя ');
    expect(link.host, 'viora.example.com');
    expect(link.query, isEmpty);
    expect(link.toString(), isNot(contains('private')));
    final payload =
        jsonDecode(Uri.decodeComponent(link.fragment)) as Map<String, dynamic>;
    expect(payload['title'], track.title);
    expect(payload['seconds'], 37);
    expect(payload['note'], 'Для тебя');
  });

  test('round trip, malformed links and exact collaborator matching', () {
    const track = Track(
      'a',
      'Песня',
      'A, B',
      Colors.red,
      performers: ['A', 'B'],
    );
    final link = momentLink(track, const Duration(seconds: 43), '100% # ?');
    final moment = ReceivedMoment.parse(link)!;
    expect(moment.note, '100% # ?');
    expect(
      ReceivedMoment.parse(
        Uri.parse('viora://moment#${link.fragment}'),
      )!.seconds,
      43,
    );
    expect(
      ReceivedMoment.parse(Uri.parse('https://evil.test/#${link.fragment}')),
      isNull,
    );
    expect(ReceivedMoment.parse(Uri.parse('viora://moment#%25bad')), isNull);
    expect(
      moment
          .matches([track, const Track('b', 'Песня', 'A', Colors.red)])
          .map((t) => t.id),
      ['a'],
    );
  });
}
