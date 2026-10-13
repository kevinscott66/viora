import 'mood_wave.dart';
import 'package:flutter/material.dart';
import '../controllers/music_controller.dart';
import '../models/artist.dart';
import '../models/track.dart';
import 'artists.dart';
import 'shared.dart';

class Discover extends StatefulWidget {
  const Discover({
    super.key,
    required this.music,
    required this.onTrack,
    required this.onPlayer,
    required this.onImport,
    required this.onSearch,
    required this.trackRow,
  });
  final MusicController music;
  final void Function(Track, List<Track>) onTrack;
  final VoidCallback onImport, onSearch, onPlayer;
  final Widget Function(Track) trackRow;
  @override
  State<Discover> createState() => _DiscoverState();
}

class _DiscoverState extends State<Discover> {
  int page = 0;
  final pages = PageController(viewportFraction: .91);
  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  void artist(ArtistCollection a) =>
      openArtist(context, artist: a, music: widget.music);
  Widget heading(String title, {String? action, VoidCallback? onTap}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.6,
                ),
              ),
            ),
            if (action != null)
              TextButton(onPressed: onTap, child: Text(action)),
          ],
        ),
      );
  @override
  Widget build(BuildContext context) {
    final music = widget.music;
    final artists = music.artists;
    final featured = artists.take(5).toList();
    final featuredTracks = <Track>[];
    final used = <String>{};
    // One release per artist first, then fill with other releases.
    for (final a in artists) {
      final t = a.cover;
      if (used.add('${t.artist}|${t.album.isEmpty ? t.title : t.album}')) {
        featuredTracks.add(t);
      }
      if (featuredTracks.length == 12) break;
    }
    final scale = MediaQuery.textScalerOf(context);
    return CustomScrollView(
      key: const PageStorageKey('discover'),
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'viora',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.8,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Поиск музыки',
                    onPressed: widget.onSearch,
                    icon: const Icon(Icons.search_rounded),
                  ),
                  IconButton(
                    tooltip: 'Добавить музыку',
                    onPressed: widget.onImport,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'На вашей волне',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${trackCount(music.catalog.length)} · любимые исполнители · ваша коллекция',
                  style: const TextStyle(color: secondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: HomeMoodWaves(music: music)),
        if (featured.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: SizedBox(
              height: 348 + (scale.scale(16) - 16) * 5,
              child: PageView.builder(
                controller: pages,
                itemCount: featured.length,
                onPageChanged: (i) => setState(() => page = i),
                itemBuilder: (context, i) {
                  final a = featured[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ArtistPortrait(a, radius: 24),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0x22000000),
                                  Color(0x33000000),
                                  Color(0xee08090c),
                                ],
                                stops: [0, .35, 1],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 20,
                            left: 20,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'В ЦЕНТРЕ ВНИМАНИЯ',
                                style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 1.3,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.info.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 31,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${trackCount(a.tracks.length)} в коллекции',
                                  style: const TextStyle(
                                    color: Color(0xffe0dce2),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: music.ready
                                          ? () {
                                              music.playCollection(a.tracks);
                                              widget.onPlayer();
                                            }
                                          : null,
                                      icon: const Icon(
                                        Icons.play_arrow_rounded,
                                      ),
                                      label: const Text('Слушать'),
                                    ),
                                    TextButton(
                                      onPressed: () => artist(a),
                                      child: const Text(
                                        'Об артисте',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
          SliverToBoxAdapter(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                featured.length,
                (i) => Semantics(
                  selected: page == i,
                  child: IconButton(
                    tooltip: 'Превью ${featured[i].info.name}',
                    onPressed: () => pages.animateToPage(
                      i,
                      duration: motion(context, 280),
                      curve: Curves.easeOut,
                    ),
                    icon: AnimatedContainer(
                      duration: motion(context, 200),
                      width: page == i ? 22 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: page == i
                            ? const Color(0xffffbac8)
                            : Colors.white24,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: heading(
              'Из вашей коллекции',
              action: 'Все треки',
              onTap: widget.onSearch,
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 224 + (scale.scale(14) - 14) * 3,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: featuredTracks.length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (context, i) {
                  final t = featuredTracks[i];
                  return SizedBox(
                    width: 152,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => widget.onTrack(t, List.of(featuredTracks)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              Cover(t, size: 152, radius: 14),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            t.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: secondary,
                              fontSize: 12,
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
          SliverToBoxAdapter(
            child: heading(
              'Музыканты',
              action: 'Все',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ArtistsScreen(music: music),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 184 + (scale.scale(14) - 14) * 3,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: artists.length.clamp(0, 12),
                itemBuilder: (context, i) => SizedBox(
                  width: 136,
                  child: ArtistTile(
                    artists[i],
                    onTap: () => artist(artists[i]),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: heading('Все треки')),
          SliverList.builder(
            itemCount: music.catalog.length,
            itemBuilder: (context, i) => widget.trackRow(music.catalog[i]),
          ),
        ] else
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: FilledButton.icon(
                onPressed: widget.onImport,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Добавить музыку'),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}
