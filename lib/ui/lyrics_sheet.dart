import 'package:flutter/material.dart';
import '../controllers/music_controller.dart';
import '../models/lyrics.dart';
import '../models/lyric_selection.dart';
import '../models/track.dart';
import '../services/lyrics_store.dart';
import 'moment_composer.dart';
import '../services/moment_link.dart';
import 'player_backdrop.dart';
import 'lyrics_follow_view.dart';

class LyricsScreen extends StatefulWidget {
  const LyricsScreen({
    super.key,
    required this.music,
    required this.track,
    this.replyTo,
    this.chatId,
  });
  final MusicController music;
  final Track track;
  final ReceivedMoment? replyTo;
  final String? chatId;
  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  late final Future<TrackLyrics> lyrics = loadLyrics(widget.track);
  final followKey = GlobalKey<LyricsFollowViewState>();
  late bool selecting = (widget.replyTo != null || widget.chatId != null);
  final selected = LyricSelection();

  void toggleLine(int index, TrackLyrics data) {
    if (!selected.toggle(index, data)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите до 3 строк и 150 символов'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      selecting = true;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: PlayerBackdrop(
      track: widget.track,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              child: Row(
                children: [
                  IconButton(
                    tooltip: selecting ? 'Отменить выбор' : 'Назад',
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: () {
                      if (selecting && widget.replyTo == null) {
                        setState(() {
                          selecting = false;
                          selected.clear();
                        });
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          selecting ? 'Выберите строки' : widget.track.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'ArtistSans',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selecting
                              ? 'Выбрано: ${selected.length} из 3'
                              : 'Удерживайте строку, чтобы поймать момент',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'ArtistSans',
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            if ((widget.replyTo != null || widget.chatId != null))
              TextButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Написать свои слова'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => MomentComposer(
                      track: widget.track,
                      position: Duration.zero,
                      duration: Duration(milliseconds: widget.track.durationMs),
                      replyTo: widget.replyTo,
                      chatId: widget.chatId,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: FutureBuilder<TrackLyrics>(
                future: lyrics,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Не удалось загрузить текст песни'),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snapshot.data!;
                  if (data.cues.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Синхронизированный текст пока готовится.'),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      if (data.automatic)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Автоматическое распознавание · возможны ошибки',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      Expanded(
                        child: ListenableBuilder(
                          listenable: Listenable.merge([
                            widget.music,
                            widget.music.playbackProgress,
                          ]),
                          builder: (context, _) {
                            final current =
                                widget.music.current.id == widget.track.id;
                            final active = current
                                ? data.indexAt(widget.music.position)
                                : -1;
                            return LyricsFollowView(
                              key: followKey,
                              active: active,
                              followEnabled: !selecting && current,
                              count: data.cues.length,
                              itemBuilder: (context, i) {
                                final cue = data.cues[i];
                                final picked = selected.contains(i);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Semantics(
                                    selected: selecting ? picked : i == active,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onLongPress: () => toggleLine(i, data),
                                        onTap: () {
                                          if (selecting) {
                                            toggleLine(i, data);
                                          } else if (current) {
                                            followKey.currentState?.resume();
                                            widget.music.seek(
                                              cue.startMs / 1000,
                                            );
                                          }
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: picked
                                                ? Colors.white
                                                : (i == active && !selecting
                                                      ? Colors.white10
                                                      : Colors.transparent),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            cue.text,
                                            style: TextStyle(
                                              fontFamily: 'ArtistSans',
                                              fontSize: 25,
                                              fontWeight: FontWeight.w700,
                                              height: 1.25,
                                              color: picked
                                                  ? const Color(0xff18171c)
                                                  : (i == active && !selecting
                                                        ? Colors.white
                                                        : Colors.white60),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xff18171c),
                            minimumSize: const Size(220, 54),
                          ),
                          onPressed: selecting && selected.isEmpty
                              ? null
                              : () {
                                  if (!selecting) {
                                    setState(() => selecting = true);
                                    return;
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => MomentComposer(
                                        track: widget.track,
                                        position: selected.position(data),
                                        duration: Duration(
                                          milliseconds: widget.track.durationMs,
                                        ),
                                        initialLyric: selected.text(data),
                                        replyTo: widget.replyTo,
                                        chatId: widget.chatId,
                                      ),
                                    ),
                                  );
                                },
                          child: Text(
                            selecting ? 'Продолжить' : 'Выбрать строки',
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
