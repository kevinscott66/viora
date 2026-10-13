import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:spun_music/models/favorite_fragment.dart';
import 'package:spun_music/models/track.dart';
import 'package:spun_music/controllers/music_controller.dart';
import 'package:spun_music/services/fragment_store_native.dart';
import 'package:spun_music/services/fragment_repository.dart';
import 'package:spun_music/ui/fragments.dart';
import 'support/queue_player.dart';

final song = Track(
  'song',
  'Песня',
  'Артист',
  Colors.pink,
  localUri: 'file:///song.mp3',
  durationMs: 120000,
);
FavoriteFragment clip(String id, {int start = 10000, int end = 25000}) =>
    FavoriteFragment(
      id: id,
      trackId: song.id,
      title: song.title,
      artist: song.artist,
      startMs: start,
      endMs: end,
      collection: 'Мурашки',
    );

class ClipPlayer extends QueuePlayer {
  List<AudioSource> sources = [];
  Duration cursorTime = Duration.zero;
  LoopMode loop = LoopMode.all;
  @override
  Duration get position => cursorTime;
  @override
  LoopMode get loopMode => loop;
  @override
  Future<void> setLoopMode(LoopMode value) async {
    loop = value;
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    cursorTime = position ?? Duration.zero;
  }

  @override
  Future<Duration?> setAudioSources(
    List<AudioSource> sources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    ShuffleOrder? shuffleOrder,
  }) async {
    this.sources = sources;
    cursorTime = initialPosition ?? Duration.zero;
    return null;
  }
}

class MemoryFragments implements FragmentRepository {
  List<FavoriteFragment> entries = [];
  @override
  Future<List<FavoriteFragment>> load() async => entries;
  @override
  Future<void> save(FavoriteFragment e) async {
    entries.removeWhere((v) => v.id == e.id);
    entries.add(e);
  }

  @override
  Future<void> delete(FavoriteFragment e) async =>
      entries.removeWhere((v) => v.id == e.id);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native store retains two fragments of same song and edits without erasing sibling',
    () async {
      final dir = await Directory.systemTemp.createTemp('fragments');
      addTearDown(() => dir.delete(recursive: true));
      final store = FragmentStore(directory: dir);
      await store.save(clip('a'));
      await store.save(clip('b', start: 40000, end: 55000));
      await store.save(clip('a', end: 30000));
      final restored = await store.load();
      expect(restored.length, 2);
      expect(restored.singleWhere((e) => e.id == 'a').endMs, 30000);
      await store.delete(clip('a'));
      expect((await store.load()).single.id, 'b');
    },
  );
  test('rejects invalid ranges and unsafe file identifiers', () {
    for (final value in [
      clip('../x'),
      clip('x', end: 10000),
      clip('x', start: -1),
    ]) {
      expect(
        () => FavoriteFragment.fromJson(value.toJson()),
        throwsFormatException,
      );
    }
  });
  test('corrupt storage surfaces error without rewriting files', () async {
    final dir = await Directory.systemTemp.createTemp('fragments');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/bad.json');
    await file.writeAsString('{');
    await expectLater(
      FragmentStore(directory: dir).load(),
      throwsFormatException,
    );
    expect(await file.readAsString(), '{');
  });
  test(
    'native clip boundaries, absolute seeking, full song and normal queues',
    () async {
      final player = ClipPlayer();
      final music = MusicController(audioPlayer: player)..ready = true;
      music.catalog.add(song);
      await music.playFragment(song, clip('a'));
      expect(music.error, isNull);
      final source = player.sources.single as ClippingAudioSource;
      expect(source.start, const Duration(seconds: 10));
      expect(source.end, const Duration(seconds: 25));
      expect(player.loopMode, LoopMode.off);
      expect(player.shuffleModeEnabled, false);
      expect(music.position, const Duration(seconds: 10));
      await music.seek(18);
      expect(player.position, const Duration(seconds: 8));
      await music.seek(100);
      expect(player.position, const Duration(seconds: 15));
      await music.seek(0);
      expect(player.position, Duration.zero);
      await music.seek(18);
      await music.playFullSong();
      expect(music.fragment, isNull);
      expect(player.sources.single, isA<UriAudioSource>());
      expect(player.position, const Duration(seconds: 18));
      await music.playFragment(song, clip('b'));
      await music.playCollection([song]);
      expect(music.fragment, isNull);
      expect(player.position, Duration.zero);
      music.dispose();
    },
  );
  testWidgets('editor saves collection and screen exposes saved fragment', (
    tester,
  ) async {
    final store = MemoryFragments();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => FragmentEditor(
                    track: song,
                    position: const Duration(seconds: 10),
                    store: store,
                  ),
                ),
              ),
              child: const Text('Добавить'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Добавить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField).first, 'Мурашки');
    await tester.scrollUntilVisible(
      find.text('Сохранить фрагмент'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Сохранить фрагмент'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.entries.single.startMs, 10000);
    expect(store.entries.single.endMs, 25000);
    final music = MusicController(audioPlayer: ClipPlayer())..ready = true;
    music.catalog.add(song);
    await tester.pumpWidget(
      MaterialApp(
        home: FragmentsScreen(music: music, store: store),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Песня'), findsOneWidget);
    expect(find.text('Полная песня'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'несуществующий');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Песня'), findsNothing);
    music.dispose();
  });
}
