import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/moment_link.dart';
import '../models/track.dart';
import 'player_backdrop.dart';
import 'shared.dart';

/// Content-sized export surface shared by preview and PNG capture.
class MomentCard extends StatelessWidget {
  const MomentCard({
    super.key,
    required this.track,
    required this.position,
    required this.lyric,
    required this.note,
    this.phase = 0,
    this.replyTo,
  });
  final Track track;
  final Duration position;
  final String lyric, note;
  final double phase;
  final ReceivedMoment? replyTo;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: Stack(
      children: [
        Positioned.fill(
          child: PlayerBackdrop(track: track, child: const SizedBox.expand()),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(
                    math.cos(phase * math.pi * 2) * .9,
                    math.sin(phase * math.pi * 2) * .8,
                  ),
                  radius: 1.25,
                  colors: [
                    Colors.white.withValues(alpha: .13),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'viora / ',
                      style: TextStyle(fontFamily: 'SpunSans'),
                    ),
                    TextSpan(
                      text: 'ЛОВИ МОМЕНТ',
                      style: TextStyle(fontFamily: 'ArtistSans'),
                    ),
                  ],
                ),
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              if (replyTo != null) ...[
                const SizedBox(height: 12),
                Text(
                  'В ответ на «${replyTo!.title}»',
                  style: const TextStyle(
                    fontFamily: 'ArtistSans',
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: Cover(track, radius: 12),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          style: const TextStyle(
                            fontFamily: 'ArtistSans',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          track.artistNames.join(' · '),
                          style: const TextStyle(
                            fontFamily: 'ArtistSans',
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (lyric.trim().isNotEmpty) ...[
                const SizedBox(height: 32),
                Text(
                  lyric.trim(),
                  key: const ValueKey('moment-quote'),
                  style: const TextStyle(
                    fontFamily: 'ArtistSans',
                    fontSize: 26,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              const Divider(color: Colors.white24),
              const SizedBox(height: 12),
              Text(
                '↗ ${formatTime(position)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              if (note.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  note.trim(),
                  style: const TextStyle(
                    fontFamily: 'ArtistSans',
                    fontSize: 15,
                    height: 1.4,
                    color: Colors.white70,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
