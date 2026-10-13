import 'package:flutter/material.dart';
import '../controllers/music_controller.dart';
import '../services/lyrics_store.dart';
import 'shared.dart';
import 'moment_composer.dart';
import 'lyrics_sheet.dart';
import 'track_swipe.dart';
import 'artists.dart';
import 'artist_credits.dart';
import 'player_controls.dart';
import 'queue_sheet.dart';
import 'player_layout.dart';
import 'player_backdrop.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key, required this.music});
  final MusicController music;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: music,
    builder: (context, _) {
      final track = music.current;
      return Scaffold(
        body: PlayerBackdrop(
          track: track,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 700;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 1020 : 460),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                tooltip: 'Назад в библиотеку',
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 30,
                                ),
                              ),
                              const Expanded(
                                child: Text(
                                  'СЕЙЧАС ИГРАЕТ',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                              FavoriteButton(
                                selected: music.favorites.contains(track.id),
                                onPressed: () => music.favorite(track),
                              ),
                            ],
                          ),
                        ),
                        if (music.fragment != null)
                          TextButton.icon(
                            onPressed: music.playFullSong,
                            icon: const Icon(Icons.open_in_full, size: 16),
                            label: const Text('Играет фрагмент · Полная песня'),
                          ),
                        Expanded(
                          child: PlayerLayout(
                            wide: wide,
                            artwork: TrackSwipe(
                              onNext: () {
                                music.trace('ui.player.swipe', {
                                  'direction': 'next',
                                });
                                return music.next();
                              },
                              onPrevious: () {
                                music.trace('ui.player.swipe', {
                                  'direction': 'previous',
                                });
                                return music.previous(restartCurrent: false);
                              },
                              child: artwork(context),
                            ),
                            details: details(context),
                            controls: PlayerControls(
                              key: ValueKey(track.id),
                              music: music,
                            ),
                            footer: footer(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );
  Widget artwork(BuildContext context) => AnimatedSwitcher(
    duration: motion(context, 380),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeOutCubic,
    transitionBuilder: (child, animation) {
      final entering = child.key == ValueKey(music.current.id);
      final direction = music.transitionDirection.toDouble();
      return SlideTransition(
        position: Tween<Offset>(
          begin: Offset(entering ? direction : -direction, 0),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      );
    },
    layoutBuilder: (current, previous) => ClipRect(
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final child in previous)
            IgnorePointer(child: ExcludeSemantics(child: child)),
          ?current,
        ],
      ),
    ),
    child: Container(
      key: ValueKey(music.current.id),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .3),
            blurRadius: 32,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: Cover(music.current, radius: 10),
      ),
    ),
  );
  Widget details(BuildContext context) => AnimatedSwitcher(
    duration: motion(context, 420),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeOutCubic,
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.topCenter,
      children: [
        for (final child in previous)
          ExcludeSemantics(child: IgnorePointer(child: child)),
        ?current,
      ],
    ),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .08),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: Column(
      key: ValueKey(music.current.id),
      children: [
        Text(
          music.current.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 8),
        if (music.artistDirectory.forTrack(music.current).isNotEmpty)
          ArtistCredits(
            artists: music.artistDirectory.forTrack(music.current),
            onSelected: (artist) => openArtist(
              context,
              artist: artist,
              music: music,
              returnToPlayer: true,
            ),
          )
        else
          Text(
            music.current.artist,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xffeee0e4)),
          ),
        const SizedBox(height: 13),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white30),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            music.current.album.isNotEmpty
                ? music.current.album
                : 'МОЯ МУЗЫКА · OFFLINE',
            style: TextStyle(
              fontSize: 8,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
  Widget footer(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(
          child: Row(
            children: [
              Icon(Icons.graphic_eq_rounded, size: 15, color: Colors.white70),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Feel every beat.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Текст песни',
          onPressed: () {
            final track = music.current;
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => LyricsScreen(music: music, track: track),
              ),
            );
          },
          icon: const Icon(Icons.lyrics_outlined, size: 21),
        ),
        IconButton(
          tooltip: 'Лови момент',
          onPressed: () async {
            final track = music.current;
            final position = music.position;
            final duration = music.duration;
            music.trace('ui.moment.open', {
              'trackId': track.id,
              'positionMs': position.inMilliseconds,
            });
            final lyrics = await loadLyrics(track);
            if (!context.mounted) return;
            final index = lyrics.indexAt(position);
            final composer = MomentComposer(
              track: track,
              position: position,
              duration: duration,
              initialLyric: index < 0 ? '' : lyrics.cues[index].text,
            );
            Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => composer),
            );
          },
          icon: const Icon(Icons.ios_share_rounded, size: 21),
        ),
        IconButton(
          tooltip: 'Открыть очередь',
          onPressed: () {
            music.trace('ui.queue.open');
            showMusicQueue(context, music);
          },
          icon: const Icon(Icons.queue_music_rounded, size: 23),
        ),
      ],
    ),
  );
}
