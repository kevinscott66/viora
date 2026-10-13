import 'mini_player.dart';
import 'package:flutter/material.dart';
import '../controllers/music_controller.dart';
import '../models/track.dart';
import '../services/moment_link.dart';
import 'player.dart';
import 'moment_reply.dart';

class ReceivedMomentScreen extends StatefulWidget {
  const ReceivedMomentScreen({
    super.key,
    required this.moment,
    required this.music,
  });
  final ReceivedMoment moment;
  final MusicController music;
  @override
  State<ReceivedMomentScreen> createState() => _ReceivedMomentScreenState();
}

class _ReceivedMomentScreenState extends State<ReceivedMomentScreen> {
  bool busy = false;
  Future<void> play(Track track) async {
    setState(() => busy = true);
    widget.music.trace('ui.moment.accept', {
      'trackId': track.id,
      'seconds': widget.moment.seconds,
    });
    await widget.music.playCollection(
      [track],
      startTrack: track,
      initialPosition: Duration(seconds: widget.moment.seconds),
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (widget.music.error != null) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(music: widget.music),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: MiniPlayer(music: widget.music),
    appBar: AppBar(title: const Text('Тебе отправили момент')),
    body: ListenableBuilder(
      listenable: widget.music,
      builder: (context, _) {
        final tracks = widget.moment.matches(widget.music.catalog);
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (widget.moment.replyTo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'В ответ на «${widget.moment.replyTo!.title}»',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            Text(
              widget.moment.title,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              widget.moment.artists.join(' · '),
              style: const TextStyle(fontFamily: 'ArtistSans'),
            ),
            const SizedBox(height: 24),
            Text(
              'С ${formatTime(Duration(seconds: widget.moment.seconds))}',
              style: const TextStyle(fontSize: 24),
            ),
            if (widget.moment.lyric.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '«${widget.moment.lyric}»',
                  style: const TextStyle(
                    fontSize: 22,
                    fontFamily: 'ArtistSans',
                  ),
                ),
              ),
            if (widget.moment.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(widget.moment.note),
              ),
            if (widget.music.loading)
              const Center(child: CircularProgressIndicator())
            else if (!widget.music.ready)
              const Text(
                'Библиотека пока недоступна. Вернись в библиотеку и повтори загрузку.',
              )
            else if (tracks.isEmpty)
              const Text(
                'Этого трека пока нет в твоей библиотеке. Добавь его через «Файлы» или открой источник на странице момента.',
              )
            else ...[
              if (tracks.length > 1)
                const Text('Нашлось несколько версий — выбери нужную:'),
              for (final track in tracks)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: FilledButton.icon(
                    onPressed: busy ? null : () => play(track),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      tracks.length == 1
                          ? 'Послушать момент'
                          : '${track.title} · ${track.album} · ${formatTime(Duration(milliseconds: track.durationMs))}',
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.reply_rounded),
              label: const Text('Ответить моментом'),
              onPressed: widget.music.ready && !busy
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => MomentReplyScreen(
                          music: widget.music,
                          parent: widget.moment,
                        ),
                      ),
                    )
                  : null,
            ),
            if (widget.music.error != null)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text('Не удалось открыть трек. Попробуй ещё раз.'),
              ),
          ],
        );
      },
    ),
  );
}
