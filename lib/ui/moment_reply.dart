import 'package:flutter/material.dart';
import '../controllers/music_controller.dart';
import '../models/track.dart';
import '../services/moment_link.dart';
import 'lyrics_sheet.dart';
import 'shared.dart';

/// Choosing a reply never changes the playback queue.
class MomentReplyScreen extends StatefulWidget {
  const MomentReplyScreen({
    super.key,
    required this.music,
    this.parent,
    this.chatId,
  });
  final MusicController music;
  final ReceivedMoment? parent;
  final String? chatId;
  @override
  State<MomentReplyScreen> createState() => _MomentReplyScreenState();
}

class _MomentReplyScreenState extends State<MomentReplyScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.parent == null ? 'Выбрать песню' : 'Ответить своей песней',
      ),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  widget.parent == null
                      ? 'Выберите трек для диалога'
                      : 'В ответ на «${widget.parent!.title}»',
                  style: const TextStyle(
                    fontFamily: 'ArtistSans',
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Трек или исполнитель',
                  ),
                  onChanged: (value) =>
                      setState(() => query = normalizeTrackText(value)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: widget.music,
              builder: (context, _) {
                final tracks = widget.music.catalog
                    .where(
                      (t) => normalizeTrackText(
                        '${t.title} ${t.artistNames.join(' ')}',
                      ).contains(query),
                    )
                    .toList();
                if (widget.music.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (tracks.isEmpty) {
                  return const Center(
                    child: Text('Подходящих треков пока нет'),
                  );
                }
                return ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: tracks.length,
                  itemBuilder: (context, i) {
                    final t = tracks[i];
                    return ListTile(
                      leading: SizedBox(
                        width: 48,
                        height: 48,
                        child: Cover(t, radius: 10),
                      ),
                      title: Text(t.title),
                      subtitle: Text(t.artistNames.join(' · ')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => LyricsScreen(
                              music: widget.music,
                              track: t,
                              replyTo: widget.parent,
                              chatId: widget.chatId,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
