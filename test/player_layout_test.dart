import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/controllers/music_controller.dart';
import 'package:spun_music/models/track.dart';
import 'package:spun_music/ui/player.dart';
import 'package:spun_music/ui/shared.dart';
import 'support/queue_player.dart';

void main() {
  Future<MusicController> render(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
    bool longTitle = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    final music = MusicController(audioPlayer: QueuePlayer())..ready = true;
    final track = Track(
      'sad',
      longTitle
          ? 'Очень длинное название совместной песни, которое переносится на несколько строк'
          : 'Example title 094',
      'Example artist 094',
      Colors.brown,
      album: 'ОТКРОВЕНИЯ',
      performers: ['THRILL PILL', 'Example artist 126', 'Example artist 388'],
    );
    music.catalog.add(track);
    music.queue.add(track);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          fontFamily: 'SpunSans',
          brightness: Brightness.dark,
          iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
          ),
        ),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: const EdgeInsets.only(top: 59, bottom: 34),
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: PlayerScreen(music: music),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return music;
  }

  for (final size in [
    const Size(430, 932),
    const Size(390, 844),
    const Size(375, 812),
  ]) {
    testWidgets('all player controls fit portrait $size without scrolling', (
      tester,
    ) async {
      final music = await render(tester, size);
      addTearDown(music.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Открыть очередь').hitTestable(), findsOneWidget);
      final slider = tester.getRect(find.byType(Slider));
      expect(slider.bottom, lessThanOrEqualTo(size.height - 34));
      final cover = tester.getRect(find.byType(Cover));
      expect(cover.top, greaterThanOrEqualTo(59 + 48));
      expect(cover.width, closeTo(cover.height, .01));
      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scroll.position.maxScrollExtent, closeTo(0, .01));
    });
  }
  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('long metadata with large text stays reachable $size', (
      tester,
    ) async {
      final music = await render(tester, size, textScale: 2, longTitle: true);
      addTearDown(music.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('Открыть очередь'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Открыть очередь').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
