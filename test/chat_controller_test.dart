import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/controllers/chat_controller.dart';

void main() {
  test(
    'failed retry keeps nonce and refresh after send is not dropped',
    () async {
      final gate = Completer<List<dynamic>>();
      final nonces = <String>[];
      var reads = 0;
      final c = ChatController(
        fetchPage: (_) async => ++reads == 1
            ? gate.future
            : [
                {'id': 1, 'text': 'hello'},
              ],
        sendText: (_, nonce) async {
          nonces.add(nonce);
          if (nonces.length == 1) throw Exception('offline');
        },
      );
      final polling = c.load();
      await expectLater(c.send('hello'), throwsException);
      final retry = c.send('hello');
      gate.complete([]);
      await polling;
      await retry;
      expect(nonces[0], nonces[1]);
      expect(c.messages.single['text'], 'hello');
      expect(c.sending, false);
      c.dispose();
    },
  );

  test(
    'history remains exhausted after subsequent polls and duplicates merge',
    () async {
      final c = ChatController(
        fetchPage: (before) async => before == null
            ? List.generate(100, (i) => {'id': i + 100, 'text': 'message'})
            : [
                {'id': 99, 'text': 'older'},
              ],
        sendText: (_, nonce) async {},
      );
      await c.load();
      expect(c.hasOlder, true);
      await c.load(older: true);
      await c.load();
      expect(c.hasOlder, false);
      expect(c.messages.length, 101);
      final previous = c.messages;
      var changes = 0;
      c.addListener(() => changes++);
      await c.load();
      expect(identical(c.messages, previous), true);
      expect(changes, 0);
      c.dispose();
    },
  );

  test(
    'concurrent refreshes are serialized and late results after dispose ignored',
    () async {
      final gate = Completer<List<dynamic>>();
      var calls = 0;
      final c = ChatController(
        fetchPage: (_) {
          calls++;
          return gate.future;
        },
        sendText: (_, nonce) async {},
      );
      final requests = [c.load(), c.load(), c.load()];
      expect(calls, 1);
      c.dispose();
      gate.complete([
        {'id': 1},
      ]);
      await Future.wait(requests);
      expect(calls, 1);
      expect(c.messages, isEmpty);
    },
  );
}
