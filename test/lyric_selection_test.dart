import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/models/lyrics.dart';
import 'package:spun_music/models/lyric_selection.dart';

void main() {
  test(
    'selection preserves song order, rejects excess without losing choices',
    () {
      const lyrics = TrackLyrics([
        LyricCue(100, 200, 'Первый'),
        LyricCue(200, 300, 'Второй'),
        LyricCue(300, 400, 'Третий'),
        LyricCue(400, 500, 'Четвёртый'),
      ]);
      final selection = LyricSelection();
      expect(selection.toggle(2, lyrics), isTrue);
      expect(selection.toggle(0, lyrics), isTrue);
      expect(selection.toggle(1, lyrics), isTrue);
      expect(selection.text(lyrics), 'Первый\nВторой\nТретий');
      expect(selection.position(lyrics), const Duration(milliseconds: 100));
      expect(selection.toggle(3, lyrics), isFalse);
      expect(selection.length, 3);
      expect(selection.toggle(1, lyrics), isTrue);
      expect(selection.text(lyrics), 'Первый\nТретий');
      selection.clear();
      expect(selection.isEmpty, isTrue);
    },
  );
  test(
    'length boundary includes separators and rejected updates are atomic',
    () {
      final lyrics = TrackLyrics([
        LyricCue(0, 1, 'a' * 149),
        LyricCue(1, 2, 'b'),
      ]);
      final selection = LyricSelection();
      expect(selection.toggle(0, lyrics), isTrue);
      expect(selection.toggle(1, lyrics), isFalse);
      expect(selection.text(lyrics).length, 149);
      expect(selection.toggle(-1, lyrics), isFalse);
      expect(selection.toggle(2, lyrics), isFalse);
    },
  );
}
