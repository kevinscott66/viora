import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/services/diagnostics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'persistent events preserve order and rotate previous session',
    () async {
      final root = await Directory.systemTemp.createTemp('spun-diagnostics-');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => root.path,
          );
      final directory = await Directory('${root.path}/Diagnostics').create();
      await File(
        '${directory.path}/events.jsonl',
      ).writeAsString('x' * (1024 * 1024));
      await Diagnostics.initialize();
      Diagnostics.record('intent.select', {'selectedId': 'second'});
      Diagnostics.record('player.index', {'receivedIndex': 1});
      await Diagnostics.flush();
      final events =
          (await File('${directory.path}/events.jsonl').readAsLines())
              .map((line) => jsonDecode(line) as Map<String, dynamic>)
              .toList();
      expect(events.map((e) => e['event']), [
        'session.start',
        'intent.select',
        'player.index',
      ]);
      expect(events.last['seq'], greaterThan(events.first['seq'] as int));
      expect(events.last['session'], events.first['session']);
      expect(
        await File('${directory.path}/events.1.jsonl').length(),
        1024 * 1024,
      );
      await root.delete(recursive: true);
    },
  );
}
