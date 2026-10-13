import 'mini_player.dart';
import 'package:flutter/material.dart';
import '../models/artist.dart';
import '../models/track.dart';
import '../controllers/music_controller.dart';
import 'artwork_provider.dart';
import 'shared.dart';
import 'player.dart';

Future<void> openArtist(
  BuildContext context, {
  required ArtistCollection artist,
  required MusicController music,
  bool returnToPlayer = false,
}) {
  music.trace('ui.artist.open', {'artist': artist.info.name});
  FocusManager.instance.primaryFocus?.unfocus();
  return Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'artist'),
      builder: (_) => ArtistScreen(
        artist: artist,
        music: music,
        returnToPlayer: returnToPlayer,
      ),
    ),
  );
}

class ArtistPortrait extends StatelessWidget {
  const ArtistPortrait(this.artist, {super.key, this.size, this.radius = 16});
  final ArtistCollection artist;
  final double? size;
  final double radius;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: artist.info.imagePath == null
        ? placeholder()
        : Image(
            image: artworkProvider(artist.info.imagePath!),
            width: size,
            height: size,
            fit: BoxFit.cover,
            alignment: Alignment(0, artist.info.imageAlignmentY),
            semanticLabel: artist.info.name,
            errorBuilder: (_, _, _) => placeholder(),
          ),
  );
  Widget placeholder() => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [artist.cover.color, const Color(0xff191922)],
      ),
    ),
    alignment: Alignment.center,
    child: Semantics(
      label: 'Исполнитель ${artist.info.name}',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            artist.info.name.characters.first.toUpperCase(),
            style: const TextStyle(
              fontSize: 76,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    ),
  );
}

class ArtistTile extends StatelessWidget {
  const ArtistTile(this.artist, {super.key, required this.onTap});
  final ArtistCollection artist;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        'Исполнитель ${artist.info.name}, ${trackCount(artist.tracks.length)}',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            ArtistPortrait(artist, size: 104, radius: 60),
            const SizedBox(height: 12),
            Text(
              artist.info.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              trackCount(artist.tracks.length),
              style: const TextStyle(color: secondary, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class ArtistScreen extends StatelessWidget {
  const ArtistScreen({
    super.key,
    required this.artist,
    required this.music,
    this.returnToPlayer = false,
  });
  final ArtistCollection artist;
  final MusicController music;
  final bool returnToPlayer;
  Future<void> player(
    BuildContext context, {
    Track? track,
    bool shuffle = false,
  }) async {
    music.trace('ui.artist.play', {
      'artist': artist.info.name,
      'selectedId': track?.id,
      'shuffleRequested': shuffle,
    });
    final currentArtist = music.artistDirectory.find(artist.info.name);
    if (currentArtist == null) return;
    if (track == null) {
      await music.playCollection(currentArtist.tracks, shuffle: shuffle);
    } else {
      await music.playCollection(currentArtist.tracks, startTrack: track);
    }
    if (!context.mounted) return;
    if (returnToPlayer) {
      Navigator.pop(context);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'player'),
        builder: (_) => PlayerScreen(music: music),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: music,
    builder: (context, _) {
      final artist = music.artistDirectory.find(this.artist.info.name);
      if (artist == null) {
        return Scaffold(
          bottomNavigationBar: MiniPlayer(
            music: music,
            returnToPlayer: returnToPlayer,
          ),
          appBar: AppBar(title: Text(this.artist.info.name)),
          body: const Center(
            child: Text('В библиотеке больше нет треков этого исполнителя.'),
          ),
        );
      }
      final albums = artist.tracks
          .map((t) => t.album)
          .where((a) => a.isNotEmpty)
          .toSet();
      return Scaffold(
        bottomNavigationBar: MiniPlayer(
          music: music,
          returnToPlayer: returnToPlayer,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverAppBar(
                  expandedHeight: 380,
                  pinned: true,
                  backgroundColor: const Color(0xff171719),
                  leading: IconButton(
                    tooltip: 'Назад',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        ArtistPortrait(artist, radius: 0),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x55000000),
                                Color(0x33000000),
                                Color(0xff171719),
                              ],
                              stops: [0, .45, 1],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 24,
                          right: 24,
                          bottom: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ИСПОЛНИТЕЛЬ',
                                style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 2,
                                  color: secondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                artist.info.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${trackCount(artist.tracks.length)} в вашей библиотеке',
                                style: const TextStyle(color: secondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (artist.info.genre.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              artist.info.genre,
                              style: const TextStyle(color: secondary),
                            ),
                          ),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: music.ready
                                  ? () => player(context)
                                  : null,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Слушать'),
                            ),
                            OutlinedButton.icon(
                              onPressed: music.ready
                                  ? () => player(context, shuffle: true)
                                  : null,
                              icon: const Icon(Icons.shuffle_rounded),
                              label: const Text('Перемешать'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '${artist.duration.inMinutes} мин музыки · ${albums.length} релизов',
                          style: const TextStyle(
                            color: secondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'В вашей коллекции',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList.builder(
                  itemCount: artist.tracks.length,
                  itemBuilder: (context, i) {
                    final t = artist.tracks[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 4,
                      ),
                      leading: Cover(t, size: 52),
                      onTap: () => player(context, track: t),
                      title: Text(
                        t.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        t.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: secondary, fontSize: 12),
                      ),
                      trailing: FavoriteButton(
                        selected: music.favorites.contains(t.id),
                        onPressed: () => music.favorite(t),
                      ),
                    );
                  },
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.paddingOf(context).bottom + 32,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class ArtistsScreen extends StatefulWidget {
  const ArtistsScreen({super.key, required this.music});
  final MusicController music;
  @override
  State<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends State<ArtistsScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.music,
    builder: (context, _) {
      final artists = widget.music.artists
          .where((a) => a.info.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
      return Scaffold(
        bottomNavigationBar: MiniPlayer(music: widget.music),
        appBar: AppBar(title: const Text('Музыканты')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: TextField(
                      textInputAction: TextInputAction.search,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      onSubmitted: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      onChanged: (v) => setState(() => query = v),
                      decoration: const InputDecoration(
                        labelText: 'Найти исполнителя',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  Expanded(
                    child: artists.isEmpty
                        ? const Center(child: Text('Исполнитель не найден'))
                        : GridView.builder(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 190,
                                  mainAxisExtent:
                                      200 +
                                      (MediaQuery.textScalerOf(
                                                context,
                                              ).scale(14) -
                                              14) *
                                          3,
                                ),
                            itemCount: artists.length,
                            itemBuilder: (context, i) => ArtistTile(
                              artists[i],
                              onTap: () => openArtist(
                                context,
                                artist: artists[i],
                                music: widget.music,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
