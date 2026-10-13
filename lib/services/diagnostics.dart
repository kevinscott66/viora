import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'diagnostics_memory.dart'
    if (dart.library.io) 'diagnostics_native.dart'
    as storage;

/// Bounded, local-only structured breadcrumbs. Never blocks playback.
class Diagnostics {
  static final session = DateTime.now().toUtc().toIso8601String();
  static int _sequence = 0;
  static Future<void> _pending = Future.value();
  static Future<void> initialize() async {
    try {
      await storage.initialize();
    } catch (e) {
      debugPrint('Spun diagnostics unavailable: $e');
    }
    record('session.start', {'version': '1.4.7+14'});
  }

  static void record(String event, [Map<String, Object?> data = const {}]) {
    final line = jsonEncode({
      'time': DateTime.now().toUtc().toIso8601String(),
      'session': session,
      'seq': ++_sequence,
      'event': event,
      ...data,
    });
    _pending = _pending.then((_) => storage.append(line)).catchError((
      Object e,
    ) {
      debugPrint('Spun diagnostics write failed: $e');
    });
  }

  static Future<void> flush() => _pending;
}
