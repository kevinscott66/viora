import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/models/artist.dart';
import 'package:spun_music/models/artist_credit.dart';
import 'package:spun_music/models/track.dart';
import 'package:spun_music/controllers/music_controller.dart';
import 'package:spun_music/services/music_store_native.dart';
import 'package:spun_music/ui/artists.dart';
import 'package:spun_music/ui/artist_credits.dart';
import 'package:spun_music/ui/player.dart';
import 'support/queue_player.dart';

const collaboration = Track(
  'joint',
  'Совместный трек',
  'A feat. B',
  Colors.red,
  localUri: 'file:///joint.mp3',
  performers: ['A', 'B', ' b ', ''],
);
const solo = Track(
  'solo',
  'Сольный трек',
  'B',
  Colors.blue,
  localUri: 'file:///solo.mp3',
);

void main() {
  test(
    'credits deduplicate case, honor explicit band names and parse legacy features',
    () {
      expect(collaboration.artistNames, ['A', 'B']);
      const legacy = Track(
        '1',
        'Song',
        'A FEAT. B; C ft D x E & F',
        Colors.red,
      );
      expect(legacy.artistNames, ['A', 'B', 'C', 'D', 'E', 'F']);
      const band = Track(
        '2',
        'Song',
        'Example, Sound & Light',
        Colors.red,
        performers: ['Example, Sound & Light'],
      );
      expect(band.artistNames, ['Example, Sound & Light']);
      const missing = Track('3', 'Song', 'Неизвестный исполнитель', Colors.red);
      expect(missing.artistNames, isEmpty);
    },
  );
  test(
    'directory counts collaborations once, matches profile case and preserves Unicode',
    () {
      final directory = ArtistDirectory(
        [
          collaboration,
          collaboration,
          solo,
          const Track('unicode', 'Song', '宇多田ヒカル', Colors.red),
          const Track('other', 'Other', '東京事変', Colors.red),
          const Track('symbol', 'Track', r'A$', Colors.red),
        ],
        {'lowercase': const ArtistInfo(name: 'b', imagePath: 'portrait.jpg')},
      );
      expect(directory.find(' B ')!.tracks.map((t) => t.id), ['joint', 'solo']);
      expect(directory.find('B')!.info.imagePath, 'portrait.jpg');
      expect(directory.forTrack(collaboration).length, 2);
      expect(directory.find('A')!.tracks.single.id, 'joint');
      expect(directory.find('A\$')!.tracks.single.id, 'symbol');
      expect(directory.find('宇多田ヒカル')!.tracks.single.id, 'unicode');
      expect(directory.find('東京事変')!.tracks.single.id, 'other');
    },
  );
  test(
    'directory cache refreshes after import, removal and profile change',
    () {
      final music = MusicController(audioPlayer: QueuePlayer());
      addTearDown(music.dispose);
      music.catalog.add(collaboration);
      final before = music.artistDirectory;
      expect(identical(before, music.artistDirectory), isTrue);
      music.catalog.add(solo);
      expect(music.artistDirectory.find('B')!.tracks.length, 2);
      music.catalog.remove(collaboration);
      expect(music.artistDirectory.find('A'), isNull);
      music.artistInfo['B'] = const ArtistInfo(name: 'B', genre: 'Rock');
      expect(music.artistDirectory.find('B')!.info.genre, 'Rock');
    },
  );
  testWidgets(
    'each player credit opens its own page and returns without replacing queue',
    (tester) async {
      final music = MusicController(audioPlayer: QueuePlayer())..ready = true;
      addTearDown(music.dispose);
      music.catalog.addAll([collaboration, solo]);
      music.queue.add(collaboration);
      await tester.pumpWidget(MaterialApp(home: PlayerScreen(music: music)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      for (final name in ['A', 'B']) {
        await tester.ensureVisible(find.byKey(ValueKey(name)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pump();
        await tester.tap(find.byKey(ValueKey(name)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pump();
        expect(find.byType(ArtistScreen), findsOneWidget);
        expect(find.text(name), findsWidgets);
        expect(
          find.text(
            name == 'A'
                ? '1 трек в вашей библиотеке'
                : '2 трека в вашей библиотеке',
          ),
          findsOneWidget,
        );
        expect(music.queue.map((t) => t.id), ['joint']);
        await tester.tap(find.byTooltip('Назад'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pump();
        expect(find.byType(PlayerScreen), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('B')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      await tester.ensureVisible(find.text('Слушать'));
      await tester.tap(find.text('Слушать'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(find.byType(ArtistScreen), findsNothing);
      expect(find.byType(PlayerScreen), findsOneWidget);
      expect(music.queue.map((t) => t.id), ['joint', 'solo']);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'selecting an artist song replaces unrelated queue and starts at that song',
    (tester) async {
      final player = QueuePlayer();
      final music = MusicController(audioPlayer: player)..ready = true;
      final songs = List.generate(
        3,
        (i) => Track(
          'artist$i',
          'Artist song $i',
          'Fortuna',
          Colors.red,
          localUri: 'file:///artist$i.mp3',
        ),
      );
      const outsider = Track(
        'outside',
        'Mumble',
        'Other',
        Colors.blue,
        localUri: 'file:///outside.mp3',
      );
      music.catalog.addAll([songs[0], outsider, songs[1], songs[2]]);
      music.queue.addAll(music.catalog);
      player.enabled = true;
      player.emitOldIndexOnShuffle = true;
      addTearDown(music.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistScreen(
            artist: music.artistDirectory.find('Fortuna')!,
            music: music,
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text('Artist song 1'), 250);
      await tester.tap(find.text('Artist song 1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(music.queue.map((t) => t.id), ['artist0', 'artist1', 'artist2']);
      expect(player.cursor, 1);
      expect(music.shuffled, isFalse);
      await player.seekToNext();
      expect(music.queue[player.cursor].id, 'artist2');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('five independent artist links fit a phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final names = [
      'Example artist 388',
      'SODA LUV',
      'OG Buda',
      'MAYOT',
      'blago white',
    ];
    final track = Track(
      'many',
      'Song',
      names.join(', '),
      Colors.red,
      performers: names,
    );
    final directory = ArtistDirectory([track], {});
    final selected = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: ArtistCredits(
                artists: directory.forTrack(track),
                onSelected: (a) => selected.add(a.info.name),
              ),
            ),
          ),
        ),
      ),
    );
    for (final name in names) {
      await tester.ensureVisible(find.byKey(ValueKey(name)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey(name)));
    }
    expect(selected, names);
    expect(tester.takeException(), isNull);
  });
  final library = Platform.environment['SPUN_LIBRARY_DIR'];
  test(
    'every known credit in the local library has exactly one artist entry',
    () async {
      final store = MusicStore(directory: Directory(library!));
      final tracks = await store.load();
      final profiles = await store.loadArtists();
      expect(
        profiles.values.map((a) => artistKey(a.name)).toSet().length,
        profiles.length,
        reason: 'Artist profiles must not repeat under different casing',
      );
      final directory = ArtistDirectory(tracks, profiles);
      for (final track in tracks) {
        expect(
          track.performers.map(artistKey).toSet().length,
          track.performers.length,
          reason: 'Raw credits must not repeat: ${track.title}',
        );
        if (track.artistNames.isNotEmpty) {
          expect(
            track.artist,
            track.artistNames.join(', '),
            reason: 'Displayed credits must match performers: ${track.title}',
          );
        }
        expect(directory.forTrack(track).length, track.artistNames.length);
        for (final artist in directory.forTrack(track)) {
          expect(artist.tracks.where((t) => t.id == track.id).length, 1);
        }
      }
      // Useful audit when running against an explicitly selected personal library.
      debugPrint(
        '${tracks.length} tracks, ${directory.artists.length} artist pages verified',
      );
    },
    skip: library == null
        ? 'Set SPUN_LIBRARY_DIR to audit a local library'
        : false,
  );
}
