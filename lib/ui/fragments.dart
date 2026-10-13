import 'mini_player.dart';
import 'package:flutter/material.dart';
import '../controllers/music_controller.dart';
import '../models/track.dart';
import '../models/favorite_fragment.dart';
import '../services/fragment_repository.dart';
import '../services/fragment_store.dart';
import 'player.dart';

class FragmentEditor extends StatefulWidget {
  const FragmentEditor({
    super.key,
    required this.track,
    this.position = Duration.zero,
    this.entry,
    this.store,
  });
  final Track track;
  final Duration position;
  final FavoriteFragment? entry;
  final FragmentRepository? store;
  @override
  State<FragmentEditor> createState() => _FragmentEditorState();
}

class _FragmentEditorState extends State<FragmentEditor> {
  late final store = widget.store ?? FragmentStore();
  late final collection = TextEditingController(
    text: widget.entry?.collection ?? '',
  );
  late final note = TextEditingController(text: widget.entry?.note ?? '');
  late RangeValues range;
  List<String> collections = [];
  bool busy = false;
  double get max => widget.track.durationMs / 1000;
  @override
  void initState() {
    super.initState();
    final start =
        (widget.entry?.startMs.toDouble() ??
            widget.position.inMilliseconds.toDouble()) /
        1000;
    final safeStart = start.clamp(0.0, (max - 1).clamp(0.0, max));
    final end =
        (widget.entry?.endMs.toDouble() ?? (safeStart + 15) * 1000) / 1000;
    range = RangeValues(safeStart, end.clamp(safeStart, max));
    loadCollections();
  }

  Future<void> loadCollections() async {
    try {
      final entries = await store.load();
      if (mounted) {
        setState(
          () => collections =
              entries
                  .map((e) => e.collection)
                  .where((e) => e.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort(),
        );
      }
    } catch (_) {
      if (mounted) {
        message(
          'Не удалось загрузить коллекции. Сохранённые фрагменты не изменены.',
        );
      }
    }
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  @override
  void dispose() {
    collection.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      await store.save(
        FavoriteFragment(
          id:
              widget.entry?.id ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          trackId: widget.track.id,
          title: widget.track.title,
          artist: widget.track.artist,
          startMs: (range.start * 1000).round(),
          endMs: (range.end * 1000).round(),
          collection: collection.text.trim(),
          note: note.text.trim(),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        message('Не удалось сохранить фрагмент. Попробуйте ещё раз.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Любимые секунды')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          widget.track.title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(widget.track.artist),
        const SizedBox(height: 28),
        const Text('Выберите начало и конец фрагмента'),
        Text(
          '${formatTime(Duration(milliseconds: (range.start * 1000).round()))} — ${formatTime(Duration(milliseconds: (range.end * 1000).round()))}',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        RangeSlider(
          min: 0,
          max: max > 0 ? max : 1,
          values: range,
          labels: RangeLabels(
            range.start.toStringAsFixed(1),
            range.end.toStringAsFixed(1),
          ),
          onChanged: busy || max < 1
              ? null
              : (value) {
                  if (value.end - value.start >= 1) {
                    setState(() => range = value);
                  }
                },
        ),
        const Text(
          'При прослушивании фрагмент остановится на выбранной границе.',
        ),
        const SizedBox(height: 24),
        TextField(
          controller: collection,
          maxLength: 60,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: 'Коллекция',
            hintText: 'Например, «Мурашки»',
          ),
        ),
        if (collections.isNotEmpty)
          Wrap(
            spacing: 8,
            children: [
              for (final name in collections)
                ActionChip(
                  label: Text(name),
                  onPressed: busy ? null : () => collection.text = name,
                ),
            ],
          ),
        TextField(
          controller: note,
          maxLength: 300,
          maxLines: 3,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: 'Подпись (необязательно)',
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy || range.end <= range.start ? null : save,
          child: Text(busy ? 'Сохраняем…' : 'Сохранить фрагмент'),
        ),
      ],
    ),
  );
}

class FragmentsScreen extends StatefulWidget {
  const FragmentsScreen({super.key, required this.music, this.store});
  final MusicController music;
  final FragmentRepository? store;
  @override
  State<FragmentsScreen> createState() => _FragmentsScreenState();
}

class _FragmentsScreenState extends State<FragmentsScreen> {
  late final store = widget.store ?? FragmentStore();
  List<FavoriteFragment> entries = [];
  String? collection, error;
  String query = '';
  bool loading = true, busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final saved = await store.load();
      if (mounted) {
        setState(() {
          entries = saved;
          error = null;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Не удалось прочитать фрагменты';
          loading = false;
        });
      }
    }
  }

  Track? trackFor(FavoriteFragment e) =>
      widget.music.catalog.where((t) => t.id == e.trackId).firstOrNull;
  Future<void> open(FavoriteFragment e, {bool full = false}) async {
    final track = trackFor(e);
    if (busy || track == null || !e.fits(track)) return;
    setState(() => busy = true);
    if (full) {
      await widget.music.playCollection([
        track,
      ], initialPosition: Duration(milliseconds: e.startMs));
    } else {
      await widget.music.playFragment(track, e);
    }
    if (!mounted) return;
    setState(() => busy = false);
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(music: widget.music),
      ),
    );
  }

  Future<void> edit(FavoriteFragment e) async {
    final track = trackFor(e);
    if (track == null) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FragmentEditor(track: track, entry: e, store: store),
      ),
    );
    if (saved == true) await load();
  }

  Future<void> delete(FavoriteFragment e) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить фрагмент?'),
        content: const Text('Сам трек останется в библиотеке.'),
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
    if (yes != true) return;
    try {
      await store.delete(e);
      await load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось удалить фрагмент')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups =
        entries
            .map((e) => e.collection)
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final selected = groups.contains(collection) ? collection : null;
    final filtered = entries
        .where(
          (e) =>
              (selected == null || e.collection == selected) &&
              '${e.title} ${e.artist} ${e.note} ${e.collection}'
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      bottomNavigationBar: MiniPlayer(music: widget.music),
      appBar: AppBar(title: const Text('Любимые секунды')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: TextButton(
                onPressed: load,
                child: Text('$error · Повторить'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Сохраняйте фрагменты из плеера: «Лови момент» → закладка → «Любимые секунды».',
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Найти фрагмент',
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Все'),
                      selected: selected == null,
                      onSelected: (_) => setState(() => collection = null),
                    ),
                    for (final group in groups)
                      ChoiceChip(
                        label: Text(group),
                        selected: selected == group,
                        onSelected: (_) => setState(() => collection = group),
                      ),
                  ],
                ),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Здесь пока нет фрагментов'),
                  ),
                for (final e in filtered)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(e.title),
                            subtitle: Text(
                              '${e.artist}\n${formatTime(Duration(milliseconds: e.startMs))} — ${formatTime(Duration(milliseconds: e.endMs))}',
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) =>
                                  v == 'delete' ? delete(e) : edit(e),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  enabled:
                                      trackFor(e)?.durationMs != null &&
                                      (trackFor(e)?.durationMs ?? 0) >= e.endMs,
                                  child: const Text('Изменить'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Удалить'),
                                ),
                              ],
                            ),
                          ),
                          if (e.collection.isNotEmpty)
                            Text(
                              e.collection,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          if (e.note.isNotEmpty) Text(e.note),
                          if (trackFor(e) == null || !e.fits(trackFor(e)!))
                            const Text(
                              'Исходный трек недоступен. Фрагмент сохранён.',
                            )
                          else
                            Wrap(
                              spacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: busy ? null : () => open(e),
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Фрагмент'),
                                ),
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => open(e, full: true),
                                  child: const Text('Полная песня'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
