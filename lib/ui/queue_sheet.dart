import 'package:flutter/material.dart';
import '../controllers/music_controller.dart';
import 'shared.dart';

Future<void> showMusicQueue(BuildContext context, MusicController music) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => MusicQueueSheet(music: music),
    );

class MusicQueueSheet extends StatelessWidget {
  const MusicQueueSheet({super.key, required this.music});
  final MusicController music;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .65,
      child: ListenableBuilder(
        listenable: music,
        builder: (context, _) {
          final tracks = music.playbackQueue;
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Сейчас в очереди',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: tracks.length,
                  itemBuilder: (context, i) {
                    final t = tracks[i];
                    final selected = t.id == music.current.id;
                    return ListTile(
                      leading: Cover(t, size: 48),
                      title: Text(t.title),
                      subtitle: Text(t.artist),
                      selected: selected,
                      trailing: selected ? const Icon(Icons.graphic_eq) : null,
                      onTap: () {
                        music.trace('ui.queue.select', {'selectedId': t.id});
                        music.select(t);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
