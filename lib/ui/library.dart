import 'mini_player.dart';
import 'music_card.dart';
import 'fragments.dart';
import 'diary.dart';
import 'package:flutter/material.dart';
import '../controllers/music_controller.dart';
import '../models/track.dart';
import 'player.dart';
import 'shared.dart';
import 'discover.dart';
import 'artists.dart';
import 'chats.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.music});
  final MusicController music;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int tab = 0;
  String query = '';
  final search = TextEditingController();
  MusicController get music => widget.music;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> openPlayer([Track? track, List<Track>? collection]) async {
    FocusManager.instance.primaryFocus?.unfocus();
    music.trace('ui.library.player', {'tab': tab, 'selectedId': track?.id});
    if (track != null) {
      if (collection != null) {
        await music.playCollection(collection, startTrack: track);
      } else {
        await music.select(track);
      }
    }
    if (!mounted) return;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: 'player'),
        pageBuilder: (context, animation, secondaryAnimation) =>
            PlayerScreen(music: music),
        transitionDuration: motion(context, 500),
        reverseTransitionDuration: motion(context, 350),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
              position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                  .animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                      reverseCurve: Curves.easeInCubic,
                    ),
                  ),
              child: child,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: music,
    builder: (context, _) => Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Expanded(
                child: tab == 5
                    ? ChatsScreen(music: music)
                    : tab == 0
                    ? home()
                    : collection(),
              ),
              if (music.error != null)
                MaterialBanner(
                  content: Text(music.error!),
                  actions: [
                    TextButton(
                      onPressed: music.initialize,
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              MiniPlayer(music: music, safeBottom: false),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab == 0
            ? 0
            : tab == 1
            ? 1
            : tab == 5
            ? 2
            : 3,
        onDestinationSelected: (value) {
          FocusManager.instance.primaryFocus?.unfocus();
          music.trace('ui.tab', {'tab': value});
          setState(() => tab = [0, 1, 5, 4][value]);
        },
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.music_note_outlined),
            selectedIcon: Icon(Icons.music_note_rounded),
            label: 'Слушать',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            label: 'Поиск',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Диалоги',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music),
            label: 'Медиатека',
          ),
        ],
      ),
    ),
  );
  Widget home() => Discover(
    music: music,
    onTrack: (track, tracks) => openPlayer(track, tracks),
    onPlayer: () => openPlayer(),
    onImport: () => setState(() => tab = 4),
    onSearch: () => setState(() => tab = 1),
    trackRow: (track) => trackRow(track, collection: List.of(music.catalog)),
  );

  Widget heading(String title, String action, VoidCallback? onPressed) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 19,
                  letterSpacing: -.5,
                ),
              ),
            ),
            if (onPressed != null)
              TextButton(onPressed: onPressed, child: Text(action))
            else
              Text(
                action,
                style: const TextStyle(fontSize: 11, color: secondary),
              ),
          ],
        ),
      );
  Future<void> importMusic() async {
    await music.importMusic();
    if (!mounted || music.importMessage == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(music.importMessage!)));
  }

  Widget collection() {
    final source = tab == 2
        ? music.catalog.where((t) => music.favorites.contains(t.id))
        : tab == 4
        ? music.catalog.where((t) => t.imported)
        : tab == 3
        ? music.playbackQueue
        : music.catalog;
    final filtered = searchTracks(tab == 1 ? query : '', source);
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      '',
                      'Найди свой звук',
                      'Любимые треки',
                      'Следом за ритмом',
                      'Моя музыка',
                    ][tab],
                    style: const TextStyle(
                      fontSize: 31,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tab == 2
                        ? '${filtered.length} в вашей коллекции'
                        : tab == 4
                        ? '${filtered.length} треков · Всегда с собой'
                        : 'Все ваши треки в одном месте.',
                    style: const TextStyle(color: secondary),
                  ),
                  if (tab == 2 || tab == 3 || tab == 4) ...[
                    _LibraryShortcut(
                      leading: const Icon(Icons.auto_stories_outlined),
                      title: const Text('Дневник музыки'),
                      subtitle: const Text('Сохранённые моменты'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => DiaryScreen(music: music),
                        ),
                      ),
                    ),
                    _LibraryShortcut(
                      leading: const Icon(Icons.bookmarks_outlined),
                      title: const Text('Любимые секунды'),
                      subtitle: const Text('Фрагменты и коллекции'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => FragmentsScreen(music: music),
                        ),
                      ),
                    ),
                    _LibraryShortcut(
                      leading: const Icon(Icons.badge_outlined),
                      title: const Text('Музыкальная визитка'),
                      subtitle: const Text('Три трека обо мне'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => MusicCardEditor(music: music),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in const {
                          4: 'Все треки',
                          2: 'Избранное',
                          3: 'Очередь',
                        }.entries)
                          ChoiceChip(
                            showCheckmark: false,
                            labelStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            selectedColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: .20),
                            backgroundColor: const Color(0xff242226),
                            side: BorderSide.none,
                            label: Text(entry.value),
                            selected: tab == entry.key,
                            onSelected: (_) => setState(() => tab = entry.key),
                          ),
                      ],
                    ),
                  ],
                  if (tab == 1) ...[
                    const SizedBox(height: 24),
                    TextField(
                      textInputAction: TextInputAction.search,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      onSubmitted: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      controller: search,
                      onChanged: (v) => setState(() => query = v),
                      decoration: InputDecoration(
                        labelText: 'Трек, альбом или исполнитель',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                tooltip: 'Очистить поиск',
                                onPressed: () {
                                  search.clear();
                                  setState(() => query = '');
                                },
                                icon: const Icon(Icons.close),
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xff29292d),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                  if (tab == 4) ...[
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: music.importing || !music.ready
                          ? null
                          : importMusic,
                      icon: music.importing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_rounded),
                      label: Text(
                        music.importing
                            ? 'Добавляем музыку…'
                            : 'Добавить из Файлов',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        'Форматы и импорт',
                        style: TextStyle(fontSize: 12, color: secondary),
                      ),
                      children: [
                        Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Выберите музыку в iCloud Drive или на устройстве. MP3, M4A, WAV, AAC, FLAC, AIFF, OGG · до 200 МБ. Поддержка форматов зависит от устройства.',
                            style: TextStyle(
                              fontSize: 12,
                              color: secondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (tab == 1 &&
              music.artists.any(
                (a) => a.info.name.toLowerCase().contains(query.toLowerCase()),
              ))
            SliverToBoxAdapter(
              child: SizedBox(
                height: 195,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final a
                        in music.artists
                            .where(
                              (a) => a.info.name.toLowerCase().contains(
                                query.toLowerCase(),
                              ),
                            )
                            .take(12))
                      SizedBox(
                        width: 136,
                        child: ArtistTile(
                          a,
                          onTap: () =>
                              openArtist(context, artist: a, music: music),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab == 2
                          ? Icons.favorite_border
                          : tab == 4
                          ? Icons.library_music_outlined
                          : Icons.search_off,
                      size: 48,
                      color: secondary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      tab == 2
                          ? 'Здесь будет то, что вы любите'
                          : tab == 4
                          ? 'Дайте музыке новый дом'
                          : 'Пока ничего не нашлось',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      tab == 2
                          ? 'Нажмите на сердечко рядом с треком.'
                          : tab == 4
                          ? 'Выберите аудиофайлы. На iPhone и iPad они сохранятся в плеере и будут доступны офлайн.'
                          : 'Попробуйте другое название или имя артиста.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: secondary),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: filtered.length,
              itemBuilder: (context, i) =>
                  trackRow(filtered[i], collection: tab == 3 ? null : filtered),
            ),
        ],
      ),
    );
  }

  Future<void> removeTrack(Track track) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Убрать из плеера?'),
        content: Text(
          '«${track.title}» будет удалён из библиотеки приложения. Исходный файл в «Файлах» останется.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (remove == true) await music.removeImported(track);
  }

  Widget trackRow(Track track, {List<Track>? collection}) {
    final current = music.current.id == track.id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: current ? const Color(0xff30242b) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: 8, right: 2),
          onTap: () => openPlayer(track, collection),
          leading: Cover(track, size: 50),
          title: Text(
            track.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: current ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          subtitle: Text(
            track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: secondary),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FavoriteButton(
                selected: music.favorites.contains(track.id),
                onPressed: () => music.favorite(track),
              ),
              if (track.imported && tab == 4)
                IconButton(
                  tooltip: 'Удалить из плеера',
                  onPressed: music.importing ? null : () => removeTrack(track),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryShortcut extends StatelessWidget {
  const _LibraryShortcut({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });
  final Widget leading, title, subtitle, trailing;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Material(
      color: const Color(0xff232125),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: IconTheme(
            data: IconThemeData(
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
            child: leading,
          ),
        ),
        title: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          child: title,
        ),
        subtitle: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 12, color: Color(0xffaaa5ad)),
          child: subtitle,
        ),
        trailing: IconTheme(
          data: const IconThemeData(size: 18, color: Color(0xffaaa5ad)),
          child: trailing,
        ),
      ),
    ),
  );
}
