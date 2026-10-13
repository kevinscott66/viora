import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/controllers/music_controller.dart';
import 'package:spun_music/models/track.dart';
import 'package:spun_music/ui/library.dart';
import 'support/queue_player.dart';

void main() {
  testWidgets(
    'favorite selection replaces old queue and next stays in favorites',
    (tester) async {
      final player = QueuePlayer()..emitOldIndexOnShuffle = true;
      final music = MusicController(audioPlayer: player)..ready = true;
      addTearDown(music.dispose);
      final favorites = List.generate(
        3,
        (i) => Track(
          'fav$i',
          'Favorite $i',
          'Artist',
          Colors.red,
          localUri: 'file:///fav$i.mp3',
        ),
      );
      const other = Track(
        'other',
        'Unrelated',
        'Other',
        Colors.blue,
        localUri: 'file:///other.mp3',
      );
      music.catalog.addAll([other, ...favorites]);
      music.favorites.addAll(favorites.map((t) => t.id));
      await music.playCollection([other]);
      await tester.pumpWidget(MaterialApp(home: LibraryScreen(music: music)));
      expect(find.byType(NavigationDestination), findsNWidgets(4));
      await tester.tap(find.byIcon(Icons.library_music_outlined));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Избранное'));
      await tester.pump(const Duration(seconds: 1));
      await tester.scrollUntilVisible(
        find.text('Favorite 1'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Favorite 1'));
      await tester.pump(const Duration(seconds: 1));
      expect(music.queue.map((t) => t.id), ['fav0', 'fav1', 'fav2']);
      expect(player.cursor, 1);
      await player.seekToNext();
      expect(music.queue[player.cursor].id, 'fav2');
      expect(tester.takeException(), isNull);
    },
  );
}
