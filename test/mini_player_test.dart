import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/controllers/music_controller.dart';
import 'package:spun_music/ui/mini_player.dart';
import 'support/queue_player.dart';
import 'package:spun_music/models/track.dart';

void main() {
  testWidgets('mini player reserves space and hides for keyboard', (
    tester,
  ) async {
    final music = MusicController(audioPlayer: QueuePlayer())..ready = true;
    addTearDown(music.dispose);
    music.catalog.add(const Track('test', 'Track', 'Artist', Colors.pink));
    Widget screen(double keyboard) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: keyboard)),
        child: Scaffold(
          body: const SizedBox.expand(key: Key('body')),
          bottomNavigationBar: MiniPlayer(music: music),
        ),
      ),
    );
    await tester.pumpWidget(screen(0));
    expect(find.byTooltip('Следующий трек'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.byKey(const Key('body'))).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byType(MiniPlayer)).dy),
    );
    await tester.pumpWidget(screen(300));
    expect(find.byTooltip('Следующий трек'), findsNothing);
    await tester.pumpWidget(screen(0));
    expect(find.byTooltip('Следующий трек'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
