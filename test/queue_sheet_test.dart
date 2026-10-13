import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/controllers/music_controller.dart';
import 'package:spun_music/models/track.dart';
import 'package:spun_music/ui/queue_sheet.dart';
import 'support/queue_player.dart';

void main() {
  testWidgets('extracted queue sheet updates order and selects source index', (
    tester,
  ) async {
    final player = QueuePlayer();
    final music = MusicController(audioPlayer: player)..ready = true;
    addTearDown(music.dispose);
    final tracks = List.generate(
      3,
      (i) => Track('$i', 'Track $i', 'Artist', Colors.blue),
    );
    music.catalog.addAll(tracks);
    music.queue.addAll(tracks);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MusicQueueSheet(music: music)),
      ),
    );
    List<String> titles() => tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title as Text).data!)
        .toList();
    expect(titles(), ['Track 0', 'Track 1', 'Track 2']);
    await music.toggleShuffle();
    await tester.pump();
    expect(titles(), ['Track 2', 'Track 0', 'Track 1']);
    await tester.tap(find.text('Track 2'));
    await tester.pump();
    expect(player.cursor, 2);
    expect(tester.takeException(), isNull);
  });
}
