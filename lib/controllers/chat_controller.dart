import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/chat_crypto.dart';
import '../services/social_api.dart';

typedef FetchChatPage = Future<List<dynamic>> Function(int? before);
typedef SendChatText = Future<void> Function(String text, String nonce);

/// Owns transport state; the screen owns draft input and scroll position.
class ChatController extends ChangeNotifier {
  ChatController({required this.fetchPage, required this.sendText});

  factory ChatController.forRoom(String room, SocialApi api) {
    final crypto = ChatCrypto(api);
    return ChatController(
      fetchPage: (before) async {
        final data = await api.request(
          'GET',
          '/api/chats/$room/messages${before == null ? '' : '?before=$before'}',
        );
        return crypto.decode(room, data['messages'] as List);
      },
      sendText: (text, nonce) =>
          crypto.send(room, {'text': text, 'nonce': nonce}),
    );
  }

  final FetchChatPage fetchPage;
  final SendChatText sendText;
  List<dynamic> messages = [];
  bool hasOlder = true, sending = false, loadingOlder = false;
  String? error;
  Future<void>? _loading;
  bool _disposed = false, _loaded = false;
  String? _pendingText, _pendingNonce;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load({bool older = false, bool refresh = false}) async {
    if (_disposed) return;
    if (_loading != null && !older && !refresh) return _loading;
    // Serialize pages, but don't drop a refresh requested after sending.
    while (_loading != null) {
      await _loading;
    }
    if (_disposed || (older && !hasOlder)) return;
    final task = _fetch(older);
    _loading = task;
    try {
      await task;
    } finally {
      if (identical(_loading, task)) _loading = null;
    }
  }

  Future<void> _fetch(bool older) async {
    loadingOlder = older;
    if (older) _notify();
    try {
      final rows = await fetchPage(
        older && messages.isNotEmpty ? messages.first['id'] as int : null,
      );
      if (_disposed) return;
      final merged =
          {
              for (final m in messages) m['id'] as int: m,
              for (final m in rows) m['id'] as int: m,
            }.values.toList()
            ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
      final changed = jsonEncode(merged) != jsonEncode(messages);
      final hadError = error != null;
      if (older || !_loaded) hasOlder = rows.length == 100;
      _loaded = true;
      if (changed) messages = merged;
      error = null;
      if (changed || hadError) _notify();
    } catch (e) {
      if (!_disposed) {
        error = e.toString();
        _notify();
      }
    } finally {
      loadingOlder = false;
      if (older) _notify();
    }
  }

  Future<void> send(String text) async {
    if (_disposed || sending || text.trim().isEmpty) return;
    if (_pendingText != text) {
      _pendingText = text;
      _pendingNonce = SocialApi.nonce();
    }
    sending = true;
    _notify();
    try {
      await sendText(text, _pendingNonce!);
      _pendingText = _pendingNonce = null;
      await load(refresh: true);
    } finally {
      sending = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
