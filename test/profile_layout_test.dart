import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/controllers/music_controller.dart';
import 'package:spun_music/services/social_api.dart';
import 'package:spun_music/ui/profile.dart';
import 'support/queue_player.dart';

class _PreviewApi extends SocialApi {
  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
    bool auth = true,
  ]) async => path == '/api/sessions'
      ? {
          'sessions': [
            {'id': '1', 'label': 'iPhone 16 Plus', 'current': true},
          ],
        }
      : {
          'name': 'Саша',
          'bio': 'Ловлю музыку под настроение',
          'color': 'rose',
          'hasKeyRecovery': false,
        };
}

void main() {
  testWidgets(
    'profile keeps actions reachable on narrow, landscape and large text screens',
    (tester) async {
      final music = MusicController(audioPlayer: QueuePlayer())
        ..loading = false;
      addTearDown(music.dispose);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      for (final size in [
        const Size(375, 812),
        const Size(852, 393),
        const Size(768, 1024),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            builder: (_, child) => MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: ProfileScreen(
              key: ValueKey(size),
              music: music,
              api: _PreviewApi(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('У меня уже есть профиль'),
          250,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.text('Изменить профиль'), -250);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Изменить профиль'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Сохранить профиль'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      final output = Platform.environment['VIORA_PROFILE_PREVIEW'];
      if (output != null) {
        final icons = FontLoader('MaterialIcons');
        icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
        final font = FontLoader('Preview');
        font.addFont(rootBundle.load('assets/fonts/Manrope-Medium.ttf'));
        await font.load();
        tester.view.physicalSize = const Size(393, 852);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xff171719),
              fontFamily: 'Preview',
              colorScheme: const ColorScheme.dark(
                primary: Color(0xfff291a0),
                surface: Color(0xff232326),
              ),
            ),
            home: RepaintBoundary(
              key: key,
              child: ProfileScreen(music: music, api: _PreviewApi()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(output).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}
