import 'dart:convert';
import '../models/track.dart';

/// The fragment is decoded only in the recipient's browser, not sent to hosting.
Uri momentLink(
  Track track,
  Duration position,
  String note, {
  String lyric = '',
  ReceivedMoment? replyTo,
}) => Uri(
  scheme: 'https',
  host: 'viora.example.com',
  fragment: jsonEncode({
    'v': 1,
    if (replyTo != null) 'replyTo': replyTo.summary,
    'title': track.title,
    'artists': track.artistNames,
    'seconds': position.inSeconds.clamp(0, 86400),
    'note': note.trim(),
    if (lyric.trim().isNotEmpty) 'lyric': lyric.trim(),
    if (track.sourceUrl != null) 'source': track.sourceUrl,
  }),
);

class ReceivedMoment {
  const ReceivedMoment(
    this.title,
    this.artists,
    this.seconds,
    this.note, {
    this.lyric = '',
    this.replyTo,
  });
  final String title, note, lyric;
  final List<String> artists;
  final int seconds;
  final ReceivedMoment? replyTo;

  // Only the immediate parent is shared: no growing conversation or private note.
  Map<String, Object> get summary => {
    'v': 1,
    'title': title,
    'artists': artists,
    'seconds': seconds,
    'note': '',
    'lyric': lyric,
  };

  static ReceivedMoment? parse(Uri uri, {bool allowReply = true}) {
    if (!((uri.scheme == 'viora' && uri.host == 'moment') ||
        (uri.scheme == 'https' && uri.host == 'viora.example.com'))) {
      return null;
    }
    if (uri.fragment.isEmpty || uri.fragment.length > 12000) return null;
    try {
      final m = jsonDecode(Uri.decodeComponent(uri.fragment));
      if (m is! Map ||
          m['v'] != 1 ||
          (m['lyric'] != null &&
              (m['lyric'] is! String || (m['lyric'] as String).length > 150)) ||
          m['title'] is! String ||
          (m['title'] as String).trim().isEmpty ||
          (m['title'] as String).length > 300 ||
          m['artists'] is! List ||
          (m['artists'] as List).length > 30 ||
          (m['artists'] as List).any((a) => a is! String || a.length > 200) ||
          m['seconds'] is! int ||
          m['seconds'] < 0 ||
          m['seconds'] > 86400 ||
          m['note'] is! String ||
          (m['note'] as String).length > 500) {
        return null;
      }
      ReceivedMoment? parent;
      if (m['replyTo'] != null) {
        if (!allowReply || m['replyTo'] is! Map) return null;
        parent = parse(
          Uri(
            scheme: 'viora',
            host: 'moment',
            fragment: jsonEncode(m['replyTo']),
          ),
          allowReply: false,
        );
        if (parent == null) return null;
      }
      return ReceivedMoment(
        m['title'],
        List<String>.from(m['artists']),
        m['seconds'],
        m['note'],
        lyric: m['lyric'] ?? '',
        replyTo: parent,
      );
    } catch (_) {
      return null;
    }
  }

  List<Track> matches(Iterable<Track> catalog) {
    final credits = artists.map(normalizeTrackText).toSet();
    return catalog.where((t) {
      final own = t.artistNames.map(normalizeTrackText).toSet();
      return normalizeTrackText(t.title) == normalizeTrackText(title) &&
          credits.isNotEmpty &&
          own.length == credits.length &&
          own.containsAll(credits);
    }).toList();
  }
}
