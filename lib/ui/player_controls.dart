import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../controllers/music_controller.dart';
import '../models/track.dart';

class PlayerControls extends StatefulWidget {
  const PlayerControls({super.key, required this.music});
  final MusicController music;
  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  MusicController get music => widget.music;
  double? scrubPosition;
  int seekRevision = 0;
  double get minimum => (music.fragment?.startMs ?? 0) / 1000;
  double get maximum =>
      ((music.fragment?.endMs ?? music.duration.inMilliseconds) / 1000).clamp(
        minimum + .001,
        double.infinity,
      );
  Duration get displayedPosition => scrubPosition == null
      ? music.position
      : Duration(milliseconds: (scrubPosition! * 1000).round());

  Future<void> finishScrub(double value) async {
    final revision = ++seekRevision;
    setState(() => scrubPosition = value);
    await music.seek(value);
    if (mounted && revision == seekRevision) {
      setState(() => scrubPosition = null);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([music, music.playbackProgress]),
    builder: (context, _) => controls(context),
  );

  Widget controls(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .14),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  tooltip: music.shuffled
                      ? 'Выключить случайный порядок'
                      : 'Случайный порядок',
                  isSelected: music.shuffled,
                  onPressed: music.ready ? music.toggleShuffle : null,
                  icon: Icon(
                    Icons.shuffle_rounded,
                    size: 21,
                    color: music.shuffled
                        ? const Color(0xffffd9a2)
                        : Colors.white70,
                  ),
                ),
                IconButton(
                  tooltip: 'Предыдущий трек',
                  onPressed: music.ready ? music.previous : null,
                  icon: const Icon(Icons.skip_previous_rounded, size: 30),
                ),
                SizedBox(
                  width: 62,
                  height: 62,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xff17131b),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    tooltip: music.playing ? 'Пауза' : 'Воспроизвести',
                    onPressed: music.ready ? music.toggle : null,
                    icon: Icon(
                      music.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 33,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Следующий трек',
                  onPressed: music.ready ? music.next : null,
                  icon: const Icon(Icons.skip_next_rounded, size: 30),
                ),
                IconButton(
                  tooltip: switch (music.repeat) {
                    LoopMode.off => 'Повтор выключен',
                    LoopMode.all => 'Повтор всей очереди',
                    LoopMode.one => 'Повтор одного трека',
                  },
                  isSelected: music.repeat != LoopMode.off,
                  onPressed: music.ready ? music.toggleRepeat : null,
                  icon: Icon(
                    music.repeat == LoopMode.one
                        ? Icons.repeat_one_rounded
                        : Icons.repeat_rounded,
                    size: 21,
                    color: music.repeat == LoopMode.off
                        ? Colors.white70
                        : const Color(0xffffd9a2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                label: formatTime(displayedPosition),
                semanticFormatterCallback: (v) => '${v.round()} секунд',
                min: minimum,
                max: maximum,
                value: (displayedPosition.inMilliseconds / 1000).clamp(
                  minimum,
                  maximum,
                ),
                onChangeStart: music.ready
                    ? (value) {
                        seekRevision++;
                        setState(() => scrubPosition = value);
                      }
                    : null,
                onChanged: music.ready
                    ? (value) => setState(() => scrubPosition = value)
                    : null,
                onChangeEnd: music.ready ? finishScrub : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      formatTime(displayedPosition),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xffeee0e4),
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      formatTime(
                        Duration(milliseconds: (maximum * 1000).round()),
                      ),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xffeee0e4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (music.error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(music.error!, textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
    ),
  );
}
