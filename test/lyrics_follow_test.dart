import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/ui/lyrics_follow_view.dart';

void main() {
  testWidgets('centers active line, respects manual browsing and selection', (
    tester,
  ) async {
    int active = 8;
    bool enabled = true;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return LyricsFollowView(
                active: active,
                followEnabled: enabled,
                count: 20,
                itemBuilder: (_, i) => SizedBox(
                  height: i.isEven ? 100 : 70,
                  child: Center(child: Text('line $i')),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final viewport = tester.getRect(find.byType(LyricsFollowView));
    expect(
      tester.getCenter(find.text('line 8')).dy,
      closeTo(viewport.center.dy, 2),
    );
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    final manualOffset = position.pixels;
    rebuild(() => active = 10);
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(manualOffset, 1));
    expect(find.text('К текущей строке'), findsOneWidget);
    await tester.tap(find.text('К текущей строке'));
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(find.text('line 10')).dy,
      closeTo(viewport.center.dy, 2),
    );
    rebuild(() {
      enabled = false;
      active = 13;
    });
    final before = position.pixels;
    await tester.pumpAndSettle();
    expect(position.pixels, before);
    rebuild(() => enabled = true);
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(find.text('line 13')).dy,
      closeTo(viewport.center.dy, 2),
    );
    expect(tester.takeException(), isNull);
  });
}
