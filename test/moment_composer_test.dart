import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/models/track.dart';
import 'package:spun_music/ui/moment_composer.dart';

void main() {
  testWidgets('long quote is fully laid out and card grows on narrow screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const quote =
        'Первая длинная строка для проверки переноса текста\n'
        'Вторая длинная строка полностью остаётся в карточке\n'
        'Третья строка тоже видна целиком';
    await tester.pumpWidget(
      const MaterialApp(
        home: MomentComposer(
          track: Track(
            'test',
            'Example title 096',
            'Example artist 096',
            Colors.blue,
          ),
          position: Duration(seconds: 49),
          duration: Duration(seconds: 251),
          initialLyric: quote,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(
      find.byKey(const ValueKey('moment-quote')),
    );
    expect(text.data, quote);
    expect(text.maxLines, isNull);
    expect(text.overflow, isNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('moment-quote'))).height,
      greaterThan(200),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'moment previews note and clamps timestamp without player commands',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(
          home: MomentComposer(
            track: Track(
              'test',
              'Длинное название песни для проверки карточки',
              'Первый исполнитель, Second Artist',
              Colors.red,
            ),
            position: Duration(seconds: 300),
            duration: Duration(seconds: 120),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Начать с 02:00'), findsOneWidget);
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText == 'Почему именно этот момент?',
        ),
        'Этот припев — про нас',
      );
      await tester.pump();
      expect(find.text('Этот припев — про нас'), findsWidgets);
      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(30);
      await tester.pump();
      expect(find.text('Начать с 00:30'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
