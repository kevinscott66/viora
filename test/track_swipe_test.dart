import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/ui/track_swipe.dart';

void main() {
  testWidgets(
    'horizontal swipes switch once; short and vertical gestures do not',
    (tester) async {
      var next = 0, previous = 0;
      final pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: TrackSwipe(
              onNext: () {
                next++;
                return pending.future;
              },
              onPrevious: () async {
                previous++;
              },
              child: const SizedBox(width: 300, height: 300),
            ),
          ),
        ),
      );
      final target = find.byType(TrackSwipe);
      await tester.drag(target, const Offset(0, -100));
      await tester.drag(target, const Offset(-20, 0));
      expect(next, 0);
      await tester.drag(target, const Offset(-100, 0));
      expect(next, 1);
      await tester.drag(target, const Offset(-100, 0));
      expect(next, 1);
      pending.complete();
      await tester.pump();
      await tester.drag(target, const Offset(100, 0));
      expect(previous, 1);
    },
  );
}
