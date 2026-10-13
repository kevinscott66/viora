import 'package:flutter/material.dart';
import '../controllers/music_controller.dart';
import 'player.dart';
import 'shared.dart';

/// Shared transport. Position ticks rebuild only the progress indicator.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    super.key,
    required this.music,
    this.safeBottom = true,
    this.returnToPlayer = false,
  });
  final MusicController music;
  final bool safeBottom;
  final bool returnToPlayer;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: music,
    builder: (context, _) {
      if (music.catalog.isEmpty ||
          MediaQuery.viewInsetsOf(context).bottom > 0) {
        return const SizedBox.shrink();
      }
      return SafeArea(
        top: false,
        bottom: safeBottom,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: content(context),
          ),
        ),
      );
    },
  );
  Widget content(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: const Color(0xff363034),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      if (returnToPlayer) {
                        Navigator.pop(context);
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          settings: const RouteSettings(name: "player"),
                          builder: (_) => PlayerScreen(music: music),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Cover(music.current, size: 44, radius: 7),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  music.current.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  music.current.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: secondary,
                                    fontSize: 9,
                                    letterSpacing: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: music.playing ? 'Пауза' : 'Воспроизвести',
                  onPressed: music.ready ? music.toggle : null,
                  icon: music.loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          music.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                ),
                IconButton(
                  tooltip: 'Следующий трек',
                  onPressed: music.ready ? music.next : null,
                  icon: const Icon(Icons.skip_next_rounded),
                ),
              ],
            ),
            ListenableBuilder(
              listenable: music.playbackProgress,
              builder: (context, _) => LinearProgressIndicator(
                value:
                    (music.position.inMilliseconds /
                            music.duration.inMilliseconds.clamp(1, 1000000))
                        .clamp(0, 1),
                minHeight: 2,
                color: const Color(0xffeaa2af),
                backgroundColor: Colors.white10,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
