import 'package:flutter/material.dart';
import '../controllers/music_controller.dart';
import '../models/track.dart';
import '../services/mood_journey.dart';
import 'shared.dart';
import 'player.dart';

class MoodJourneyScreen extends StatefulWidget {
  const MoodJourneyScreen({super.key, required this.music, this.preferences});
  final MusicController music;
  final MoodPreferences? preferences;
  @override
  State<MoodJourneyScreen> createState() => _MoodJourneyScreenState();
}

class _MoodJourneyScreenState extends State<MoodJourneyScreen> {
  late final preferences = widget.preferences ?? MoodPreferences();
  Map<String, TrackMood> labels = {};
  List<Track> tracks = [];
  TrackMood start = TrackMood.calm, end = TrackMood.energetic;
  int minutes = 20;
  bool loading = true, failed = false, busy = false, favorites = false;
  List<Track> get source => widget.music.catalog
      .where((t) => !favorites || widget.music.favorites.contains(t.id))
      .toList();
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value = await preferences.load();
      if (mounted) {
        setState(() {
          labels = value;
          loading = false;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  void generate() {
    setState(
      () => tracks = buildMoodJourney(
        source,
        labels,
        start,
        end,
        Duration(minutes: minutes),
      ),
    );
    if (tracks.isEmpty) {
      message(
        'Нет отмеченных треков для выбранного настроения. Добавь отметки или измени выбор.',
      );
    }
  }

  Future<void> library({bool add = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _MoodLibrary(
          tracks: widget.music.catalog,
          labels: labels,
          preferences: preferences,
          selected: tracks.map((t) => t.id).toSet(),
          onAdd: add
              ? (track) {
                  setState(() {
                    if (!tracks.any((t) => sameRecording(t, track))) {
                      tracks.add(track);
                    }
                  });
                }
              : null,
        ),
      ),
    );
    if (mounted) {
      setState(() {
        if (!add) tracks = [];
      });
    }
  }

  Future<void> play() async {
    setState(() => busy = true);
    try {
      await widget.music.playCollection(List.of(tracks), shuffle: false);
      if (!mounted) return;
      if (widget.music.error != null) {
        message('Не удалось запустить подборку');
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PlayerScreen(music: widget.music),
        ),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget moodPicker(
    String title,
    TrackMood value,
    ValueChanged<TrackMood> change,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        children: [
          for (final mood in TrackMood.values)
            ChoiceChip(
              label: Text(mood.label),
              selected: mood == value,
              onSelected: busy
                  ? null
                  : (_) => setState(() {
                      change(mood);
                      tracks = [];
                    }),
            ),
        ],
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final total = Duration(
      milliseconds: tracks.fold<int>(0, (sum, t) => sum + t.durationMs),
    );
    final tagged = source.where((t) => labels.containsKey(t.id)).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Сменить настроение')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : failed
          ? Center(
              child: TextButton(
                onPressed: load,
                child: const Text('Не удалось прочитать отметки. Повторить'),
              ),
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [Color(0xff273e57), Color(0xff73334c)],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${start.label} → ${end.label}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Твоя музыка. Твой переход. Целые песни, без обрывов.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  moodPicker('Сейчас', start, (v) => start = v),
                  const SizedBox(height: 16),
                  moodPicker('Хочу прийти к', end, (v) => end = v),
                  const SizedBox(height: 16),
                  Text('Примерно $minutes минут'),
                  Slider(
                    value: minutes.toDouble(),
                    min: 10,
                    max: 60,
                    divisions: 10,
                    label: '$minutes мин',
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                            minutes = v.round();
                            tracks = [];
                          }),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Только избранное'),
                    value: favorites,
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                            favorites = v;
                            tracks = [];
                          }),
                  ),
                  Text(
                    'Отмечено $tagged из ${source.length} треков. Автооценки — из музыкальных каталогов. Треки без согласованных данных не размечены.',
                  ),
                  TextButton.icon(
                    onPressed: busy ? null : () => library(),
                    icon: const Icon(Icons.tune),
                    label: const Text('Отметить настроение треков'),
                  ),
                  FilledButton(
                    onPressed: busy || tagged == 0 ? null : generate,
                    child: Text(
                      tracks.isEmpty ? 'Собрать подборку' : 'Собрать иначе',
                    ),
                  ),
                  if (tagged == 0)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Начни с нескольких спокойных и энергичных песен. Отметки сохранятся для следующих подборок.',
                      ),
                    ),
                  if (tracks.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      '${tracks.length} треков · ${formatTime(total)}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (total.inMinutes < minutes - 3)
                      const Text(
                        'Отмеченных треков мало для выбранной длительности. Можно добавить песни вручную.',
                      ),
                    const Text('Удерживай трек, чтобы изменить порядок.'),
                    if (labels[tracks.first.id] != start ||
                        labels[tracks.last.id] != end)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Не хватает треков для начала или конца перехода. Добавь нужные отметки и пересобери подборку.',
                        ),
                      ),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: !busy,
                      itemCount: tracks.length,
                      onReorder: (oldIndex, newIndex) {
                        if (busy) return;
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final t = tracks.removeAt(oldIndex);
                          tracks.insert(newIndex, t);
                        });
                      },
                      itemBuilder: (context, i) {
                        final t = tracks[i];
                        return ListTile(
                          key: ValueKey(t.id),
                          contentPadding: EdgeInsets.zero,
                          leading: Cover(t, size: 44),
                          title: Text(t.title),
                          subtitle: Text(
                            '${t.artist}\n${labels[t.id]?.label ?? 'Добавлен вручную'} · ${formatTime(Duration(milliseconds: t.durationMs))}',
                          ),
                          trailing: IconButton(
                            tooltip: 'Убрать из подборки',
                            onPressed: busy
                                ? null
                                : () => setState(() => tracks.removeAt(i)),
                            icon: const Icon(Icons.close),
                          ),
                        );
                      },
                    ),
                    TextButton.icon(
                      onPressed: busy ? null : () => library(add: true),
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить трек'),
                    ),
                    FilledButton.icon(
                      onPressed: busy ? null : play,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(busy ? 'Открываем…' : 'Слушать по порядку'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _MoodLibrary extends StatefulWidget {
  const _MoodLibrary({
    required this.tracks,
    required this.labels,
    required this.preferences,
    required this.selected,
    this.onAdd,
  });
  final List<Track> tracks;
  final Map<String, TrackMood> labels;
  final MoodPreferences preferences;
  final Set<String> selected;
  final ValueChanged<Track>? onAdd;
  @override
  State<_MoodLibrary> createState() => _MoodLibraryState();
}

class _MoodLibraryState extends State<_MoodLibrary> {
  String query = '';
  bool busy = false;
  Future<void> mark(Track t, TrackMood? mood) async {
    setState(() => busy = true);
    final updated = Map<String, TrackMood>.of(widget.labels);
    if (mood == null) {
      updated.remove(t.id);
    } else {
      updated[t.id] = mood;
    }
    try {
      await widget.preferences.save(updated);
      widget.labels
        ..clear()
        ..addAll(updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить отметку')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = searchTracks(query, widget.tracks);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.onAdd == null ? 'Настроение треков' : 'Добавить в подборку',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Найти трек',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, i) {
                final t = list[i];
                return ListTile(
                  leading: Cover(t, size: 44),
                  title: Text(t.title),
                  subtitle: Text(
                    '${t.artist}\n${widget.labels[t.id]?.label ?? 'Настроение не отмечено'}',
                  ),
                  trailing: widget.onAdd != null
                      ? IconButton(
                          tooltip: 'Добавить',
                          onPressed: widget.selected.contains(t.id)
                              ? null
                              : () {
                                  widget.onAdd!(t);
                                  Navigator.pop(context);
                                },
                          icon: Icon(
                            widget.selected.contains(t.id)
                                ? Icons.check
                                : Icons.add,
                          ),
                        )
                      : PopupMenuButton<String>(
                          enabled: !busy,
                          tooltip: 'Указать настроение',
                          onSelected: (value) => mark(
                            t,
                            value == 'clear'
                                ? null
                                : TrackMood.values.byName(value),
                          ),
                          itemBuilder: (_) => [
                            for (final mood in TrackMood.values)
                              PopupMenuItem(
                                value: mood.name,
                                child: Text(mood.label),
                              ),
                            const PopupMenuItem(
                              value: 'clear',
                              child: Text('Убрать отметку'),
                            ),
                          ],
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
