import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/models/lyrics.dart';

void main() {
  test('timestamps respect gaps, endings, sorting and malformed cues', () {
    final data = TrackLyrics.decode({
      'version': 1,
      'status': 'auto',
      'cues': [
        {'startMs': 3000, 'endMs': 4000, 'text': 'Вторая'},
        {'startMs': 1000, 'endMs': 2000, 'text': 'Первая'},
        {'startMs': -1, 'endMs': 200, 'text': 'Ошибка'},
      ],
    });
    expect(data.cues.length, 2);
    expect(data.automatic, isTrue);
    expect(data.indexAt(const Duration(milliseconds: 1000)), 0);
    expect(data.indexAt(const Duration(milliseconds: 2000)), -1);
    expect(data.indexAt(const Duration(milliseconds: 3500)), 1);
    expect(TrackLyrics.decode(null).cues, isEmpty);
  });
}
