import 'package:spun_music/controllers/music_controller.dart';
import 'support/queue_player.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:spun_music/services/diary_repository.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/models/diary_entry.dart';
import 'package:spun_music/services/diary_store_native.dart';
import 'package:spun_music/services/moment_link.dart';
import 'package:spun_music/ui/diary.dart';

class MemoryDiary implements DiaryRepository {
  final entries = <DiaryEntry>[];
  @override
  Future<List<DiaryEntry>> load() async => entries;
  @override
  Future<void> save(DiaryEntry entry) async {
    entries.add(entry);
  }

  @override
  Future<void> delete(DiaryEntry entry) async {
    entries.remove(entry);
  }
}

void main() {
  late Directory directory;
  late DiaryStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('viora-diary-');
    store = DiaryStore(directory: directory);
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  DiaryEntry entry(String id, int day, {String note = 'Прогулка'}) =>
      DiaryEntry(
        id: id,
        date: DateTime(2026, 10, day),
        moment: const ReceivedMoment(
          'Песня',
          ['Артист'],
          49,
          '',
          lyric: 'Припев',
        ),
        note: note,
      );
  test(
    'survives restart, sorts and filters, edits without duplication, deletes',
    () async {
      await store.save(entry('one', 1));
      await store.save(entry('two', 3));
      final restarted = DiaryStore(directory: directory);
      final loaded = await restarted.load();
      expect(loaded.map((e) => e.id), ['two', 'one']);
      expect(loaded.first.matches('припев', DateTime(2026, 10, 3)), isTrue);
      expect(loaded.first.matches('ПРОГУЛКА', DateTime(2026, 10, 1)), isFalse);
      await restarted.save(entry('one', 1, note: 'Изменено'));
      expect((await restarted.load()).length, 2);
      expect((await restarted.load()).last.note, 'Изменено');
      await restarted.delete(entry('one', 1));
      expect((await restarted.load()).single.id, 'two');
    },
  );
  test('corrupt file is not silently discarded or overwritten', () async {
    await File('${directory.path}/broken.json').writeAsString('broken');
    await expectLater(store.load(), throwsFormatException);
    expect(
      await File('${directory.path}/broken.json').readAsString(),
      'broken',
    );
  });
  test(
    'export representation retains note, photo and cue; rejects traversal',
    () {
      final e = DiaryEntry(
        id: 'safe',
        date: DateTime(2026),
        moment: const ReceivedMoment(
          'Трек',
          ['Имя'],
          42,
          'Подпись',
          lyric: 'Строка',
        ),
        note: 'Личное',
        photo: base64Encode([1, 2, 3]),
      );
      final restored = DiaryEntry.fromJson(jsonDecode(jsonEncode(e.toJson())));
      expect(restored.note, 'Личное');
      expect(restored.moment.seconds, 42);
      expect(restored.photo, e.photo);
      expect(
        () => DiaryEntry.fromJson({...e.toJson(), 'id': '../bad'}),
        throwsFormatException,
      );
    },
  );
  test('photo is resized and remains a readable JPEG', () {
    final input = img.Image(width: 1800, height: 900);
    final encoded = diaryPhoto(Uint8List.fromList(img.encodePng(input)));
    final output = img.decodeJpg(base64Decode(encoded))!;
    expect(output.width, 1200);
    expect(output.height, 600);
  });
  testWidgets('diary search and confirmed deletion keep other entries', (
    tester,
  ) async {
    final memory = MemoryDiary();
    memory.entries.addAll([
      entry('one', 1, note: 'Первый вечер'),
      entry('two', 2, note: 'Второй вечер'),
    ]);
    final music = MusicController(audioPlayer: QueuePlayer())..ready = true;
    addTearDown(music.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: DiaryScreen(music: music, store: memory),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Первый');
    await tester.pumpAndSettle();
    expect(find.text('Первый вечер'), findsOneWidget);
    expect(find.text('Второй вечер'), findsNothing);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Удалить'));
    await tester.pumpAndSettle();
    expect(memory.entries.single.id, 'two');
    expect(tester.takeException(), isNull);
  });
  testWidgets('editor saves note and exact moment locally', (tester) async {
    final memory = MemoryDiary();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => DiaryEditor(
                    moment: const ReceivedMoment(
                      'Трек',
                      ['Артист'],
                      49,
                      '',
                      lyric: 'Слова',
                    ),
                    store: memory,
                  ),
                ),
              ),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Запомнить этот вечер');
    await tester.ensureVisible(find.text('Сохранить в дневник'));
    await tester.tap(find.text('Сохранить в дневник'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    final saved = await memory.load();
    expect(saved.single.note, 'Запомнить этот вечер');
    expect(saved.single.moment.seconds, 49);
    expect(tester.takeException(), isNull);
  });
}
