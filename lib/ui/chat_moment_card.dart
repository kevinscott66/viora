import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controllers/music_controller.dart';
import '../models/track.dart';
import '../services/moment_link.dart';
import 'artists.dart';
import 'lyrics_sheet.dart';
import 'moment_reply.dart';
import 'player.dart';
import 'player_backdrop.dart';
import 'received_moment.dart';
import 'shared.dart';

/// A real playback surface, not a flattened export image.
class ChatMomentCard extends StatefulWidget {
  const ChatMomentCard({
    super.key,
    required this.moment,
    required this.music,
    required this.chatId,
  });
  final ReceivedMoment moment;
  final MusicController music;
  final String chatId;
  @override
  State<ChatMomentCard> createState() => _ChatMomentCardState();
}

class _ChatMomentCardState extends State<ChatMomentCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController light = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );
  bool busy = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      light.stop();
    } else {
      light.repeat();
    }
  }

  @override
  void dispose() {
    light.dispose();
    super.dispose();
  }

  void details() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) =>
          ReceivedMomentScreen(moment: widget.moment, music: widget.music),
    ),
  );
  Future<void> play({bool restart = false, bool open = false}) async {
    if (busy) return;
    final tracks = widget.moment.matches(widget.music.catalog);
    if (tracks.length != 1) {
      details();
      return;
    }
    final track = tracks.single;
    setState(() => busy = true);
    try {
      final selected = widget.music.current.id == track.id;
      if (!selected || restart) {
        await widget.music.playCollection(
          [track],
          startTrack: track,
          initialPosition: Duration(seconds: widget.moment.seconds),
        );
      } else if (!open) {
        await widget.music.toggle();
      }
      if (!mounted) return;
      if (widget.music.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось воспроизвести момент')),
        );
      } else if (open) {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PlayerScreen(music: widget.music),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.music, widget.music.playbackProgress]),
    builder: (context, _) {
      final m = widget.moment;
      final matches = m.matches(widget.music.catalog);
      final track = matches.isEmpty
          ? Track(
              'missing',
              m.title,
              m.artists.join(', '),
              const Color(0xff583347),
            )
          : matches.first;
      final selected =
          matches.length == 1 && widget.music.current.id == track.id;
      final playing = selected && widget.music.playing;
      final artists = widget.music.artistDirectory.forTrack(track);
      return ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned.fill(
              child: PlayerBackdrop(
                track: track,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: light,
                  builder: (context, _) => DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(
                          math.cos(light.value * math.pi * 2) * .8,
                          math.sin(light.value * math.pi * 2) * .6,
                        ),
                        radius: 1.3,
                        colors: [
                          Colors.white.withValues(alpha: .12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'viora / ЛОВИ МОМЕНТ',
                    style: TextStyle(
                      fontFamily: 'ArtistSans',
                      fontSize: 11,
                      letterSpacing: 1.1,
                      color: Colors.white60,
                    ),
                  ),
                  if (m.replyTo != null)
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ReceivedMomentScreen(
                            moment: m.replyTo!,
                            music: widget.music,
                          ),
                        ),
                      ),
                      child: Text('В ответ на «${m.replyTo!.title}»'),
                    ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        label: 'Открыть плеер',
                        button: true,
                        child: GestureDetector(
                          onTap: busy ? null : () => play(open: true),
                          child: SizedBox(
                            width: 80,
                            height: 80,
                            child: Cover(track, radius: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: busy ? null : () => play(open: true),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Text(
                                  m.title,
                                  style: const TextStyle(
                                    fontFamily: 'ArtistSans',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 6,
                              children: [
                                for (final name in m.artists)
                                  InkWell(
                                    onTap: () {
                                      final found = artists.where(
                                        (a) =>
                                            normalizeTrackText(a.info.name) ==
                                            normalizeTrackText(name),
                                      );
                                      if (found.isNotEmpty) {
                                        openArtist(
                                          context,
                                          artist: found.first,
                                          music: widget.music,
                                        );
                                      } else {
                                        details();
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontFamily: 'ArtistSans',
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (m.lyric.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    InkWell(
                      onTap: busy ? null : () => play(restart: true),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .09),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          m.lyric,
                          style: const TextStyle(
                            fontFamily: 'ArtistSans',
                            fontSize: 23,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (m.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        m.note,
                        style: const TextStyle(
                          fontFamily: 'ArtistSans',
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: busy ? null : () => play(),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                        child: Icon(
                          busy
                              ? Icons.hourglass_top
                              : playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          semanticLabel: playing
                              ? 'Приостановить момент'
                              : 'Слушать момент',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextButton(
                          onPressed: busy ? null : () => play(restart: true),
                          child: Text(
                            '↗ ${formatTime(Duration(seconds: m.seconds))}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Открыть текст',
                        onPressed: matches.length == 1
                            ? () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => LyricsScreen(
                                    music: widget.music,
                                    track: track,
                                  ),
                                ),
                              )
                            : details,
                        icon: const Icon(Icons.lyrics_outlined),
                      ),
                    ],
                  ),
                  if (selected)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(
                        value: widget.music.duration.inMilliseconds > 0
                            ? (widget.music.position.inMilliseconds /
                                      widget.music.duration.inMilliseconds)
                                  .clamp(0.0, 1.0)
                            : 0,
                        minHeight: 2,
                        color: Colors.white,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                  if (matches.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Трек пока не добавлен в библиотеку',
                        style: TextStyle(fontSize: 12, color: Colors.white60),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => MomentReplyScreen(
                          music: widget.music,
                          parent: m,
                          chatId: widget.chatId,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.reply_rounded),
                    label: const Text('Ответить песней'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
