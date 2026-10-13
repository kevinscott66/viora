import 'package:flutter/material.dart';
import 'wave_hero.dart';
import '../services/wave_stations.dart';
import '../controllers/music_controller.dart';
import '../services/mood_journey.dart';
import '../models/track.dart';
import 'mood_journey.dart';
import 'player.dart';

List<Track> moodWaveTracks(
  Iterable<Track> source,
  Map<String, TrackMood> labels,
  TrackMood? mood, {
  TrackTone? tone,
  MoodEvidence? evidence,
}) {
  final result = <Track>[];
  for (final track in source) {
    if (track.imported &&
        (mood == null || labels[track.id] == mood) &&
        (tone == null || evidence?.tone(track.id) == tone) &&
        !result.any((t) => sameRecording(t, track))) {
      result.add(track);
    }
  }
  return result;
}

class MoodWave extends StatefulWidget {
  const MoodWave({super.key, required this.music});
  final MusicController music;
  @override
  State<MoodWave> createState() => _MoodWaveState();
}

class _MoodWaveState extends State<MoodWave> {
  Map<String, TrackMood> labels = {};
  TrackMood? mood;
  TrackTone? tone;
  MoodEvidence? evidence;
  bool favorites = false, loading = true, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value = await MoodPreferences().load();
      final sources = await MoodEvidence.load();
      if (mounted) {
        setState(() {
          labels = value;
          evidence = sources;
          loading = false;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Не удалось загрузить оценки';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.music,
    builder: (context, _) {
      final pool = moodWaveTracks(
        widget.music.catalog.where(
          (t) => !favorites || widget.music.favorites.contains(t.id),
        ),
        labels,
        mood,
        tone: tone,
        evidence: evidence,
      );
      return Scaffold(
        appBar: AppBar(title: const Text('Твоя волна')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary.withValues(alpha: .7),
                    const Color(0xff16151d),
                  ],
                ),
              ),
              child: const Icon(
                Icons.graphic_eq_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Настрой свой ритм',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Энергичность'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  showCheckmark: false,
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide.none,
                  backgroundColor: const Color(0xff252229),
                  selectedColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: .25),
                  label: const Text('Любое'),
                  selected: mood == null,
                  onSelected: busy ? null : (_) => setState(() => mood = null),
                ),
                for (final m in TrackMood.values)
                  ChoiceChip(
                    showCheckmark: false,
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide.none,
                    backgroundColor: const Color(0xff252229),
                    selectedColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .25),
                    label: Text(m.label),
                    selected: mood == m,
                    onSelected: busy ? null : (_) => setState(() => mood = m),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Эмоциональный окрас'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  showCheckmark: false,
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide.none,
                  backgroundColor: const Color(0xff252229),
                  selectedColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: .25),
                  label: const Text('Любой'),
                  selected: tone == null,
                  onSelected: busy ? null : (_) => setState(() => tone = null),
                ),
                for (final t in TrackTone.values)
                  ChoiceChip(
                    showCheckmark: false,
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide.none,
                    backgroundColor: const Color(0xff252229),
                    selectedColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .25),
                    label: Text(t.label),
                    selected: tone == t,
                    onSelected: busy ? null : (_) => setState(() => tone = t),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Только избранное'),
              value: favorites,
              onChanged: busy ? null : (v) => setState(() => favorites = v),
            ),
            Text(
              loading
                  ? 'Загружаем оценки…'
                  : '${pool.length} треков в твоей библиотеке',
            ),
            const SizedBox(height: 16),
            if (error != null)
              TextButton(onPressed: load, child: Text('$error · Повторить')),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(busy ? 'Запускаем…' : 'Включить волну'),
              onPressed: loading || busy || error != null || pool.isEmpty
                  ? null
                  : () async {
                      setState(() => busy = true);
                      await widget.music.playCollection(
                        pool,
                        shuffle: true,
                        repeatQueue: true,
                      );
                      if (!context.mounted) return;
                      setState(() => busy = false);
                      await Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => PlayerScreen(music: widget.music),
                        ),
                      );
                    },
            ),
            const SizedBox(height: 16),
            const ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Как работает волна', style: TextStyle(fontSize: 14)),
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Волна перемешивает твою музыку и повторяет очередь. Настройки применяются при запуске. Оценки каталогов описывают звучание, а не смысл слов; треки без согласованных данных доступны в общей волне.',
                    style: TextStyle(color: Color(0xffaaa5ad), height: 1.5),
                  ),
                ),
              ],
            ),
            if (evidence != null)
              TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => SizedBox(
                    height: MediaQuery.sizeOf(context).height * .75,
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const Text(
                          'Источники оценок',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Tunebat · SongData · SongBPM · Musicstax. Сопоставлены название, исполнитель и длительность. Это автоматические оценки каталогов, а не экспертная оценка настроения.',
                        ),
                        for (final track in widget.music.catalog.where(
                          (t) => t.imported,
                        ))
                          ExpansionTile(
                            title: Text(track.title),
                            subtitle: Text(
                              '${track.artist}\n${evidence!.verified(track.id)
                                  ? 'Данные найдены'
                                  : evidence!.tracks[track.id]?['status'] == 'conflict'
                                  ? 'Источники расходятся'
                                  : 'Нет подтверждённой оценки'}',
                            ),
                            children: [
                              for (final source
                                  in (evidence!.tracks[track.id]?['sources']
                                          as List? ??
                                      []))
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: SelectableText(
                                    '${source['energy'] != null ? 'Энергичность: ${source['energy']}/100' : 'Энергичность: ${source['band']}'}${source['valence'] != null ? ' · Позитивность: ${source['valence']}/100' : ''}\n${source['url']}',
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                child: Text(
                  'Данные найдены для ${widget.music.catalog.where((t) => evidence!.verified(t.id)).length} из ${widget.music.catalog.length} треков · Подробнее',
                ),
              ),
            TextButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => MoodJourneyScreen(music: widget.music),
                  ),
                );
                await load();
              },
              child: const Text('Оценки треков и плавная смена настроения'),
            ),
          ],
        ),
      );
    },
  );
}

class HomeMoodWaves extends StatefulWidget {
  const HomeMoodWaves({super.key, required this.music});
  final MusicController music;
  @override
  State<HomeMoodWaves> createState() => _HomeMoodWavesState();
}

class _HomeMoodWavesState extends State<HomeMoodWaves> {
  static const cardColors = [
    [Color(0xffff82b3), Color(0xffed4591), Color(0xff963dd9)],
    [Color(0xffffd052), Color(0xffff8a24), Color(0xfff04438)],
    [Color(0xff57f1d3), Color(0xff06c7c5), Color(0xff168be0)],
    [Color(0xff729cff), Color(0xff6854f0), Color(0xffa23ce4)],
    [Color(0xfff2ee45), Color(0xffa4df26), Color(0xff33bd74)],
  ];

  WaveStations? stations;
  bool loading = true, busy = false;
  String? error;
  int? active;
  static const presets = [
    (
      name: 'Моя волна',
      icon: Icons.waves_rounded,
      color: Color(0xffed8fa5),
      station: 'all',
      hint: 'Вся коллекция',
    ),
    (
      name: 'Плюс вайб',
      icon: Icons.celebration_rounded,
      color: Color(0xffe884d8),
      station: 'party',
      hint: 'Радость и позитив',
    ),
    (
      name: 'На грустном',
      icon: Icons.water_drop_outlined,
      color: Color(0xffab99dc),
      station: 'sad',
      hint: 'Печаль и воспоминания',
    ),
    (
      name: 'Чилл',
      icon: Icons.nightlight_round,
      color: Color(0xff79d8cb),
      station: 'night',
      hint: 'Расслабиться и выдохнуть',
    ),
    (
      name: 'Наваливай',
      icon: Icons.bolt_rounded,
      color: Color(0xffffad69),
      station: 'groove',
      hint: 'Громче и мощнее',
    ),
    (
      name: 'Про любовь',
      icon: Icons.favorite_rounded,
      color: Color(0xffff8fbd),
      station: 'romance',
      hint: 'Нежность и притяжение',
    ),
  ];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final reviewed = await WaveStations.load();
      if (mounted) {
        setState(() {
          stations = reviewed;
          loading = false;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Не удалось загрузить волну';
        });
      }
    }
  }

  Future<void> start(int index, List<Track> tracks) async {
    setState(() {
      busy = true;
      active = index;
    });
    try {
      await widget.music.playCollection(
        tracks,
        shuffle: true,
        repeatQueue: true,
        wavePreset: 'home-v2:${presets[index].station}',
      );
      if (widget.music.error != null) throw StateError('Playback failed');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось включить волну. Попробуй ещё раз.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          active = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.music,
    builder: (context, _) {
      final selected = presets.indexWhere(
        (p) => widget.music.activeWavePreset == 'home-v2:${p.station}',
      );
      final selectedPreset = presets[selected < 0 ? 0 : selected];
      final all = moodWaveTracks(widget.music.catalog, const {}, null);
      final canStart =
          !loading &&
          !busy &&
          error == null &&
          widget.music.ready &&
          all.isNotEmpty;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: WaveHero(
              accent: selectedPreset.color,
              playing:
                  widget.music.activeWavePreset != null && widget.music.playing,
              busy: busy || loading,
              mood: selected > 0 ? selectedPreset.name : null,
              onClear: canStart ? () => start(0, all) : null,
              onTap: !canStart
                  ? null
                  : () async {
                      if (widget.music.activeWavePreset != null) {
                        await widget.music.toggle();
                      } else {
                        await start(0, all);
                      }
                    },
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextButton(
                onPressed: load,
                child: Text('$error · Повторить'),
              ),
            ),
          SizedBox(
            height:
                200 +
                (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(
                      0,
                      100,
                    ) *
                    4,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              itemCount: presets.length - 1,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, cardIndex) {
                final index = cardIndex + 1;
                final p = presets[index];
                final colors = cardColors[index % cardColors.length];
                final chosen =
                    widget.music.activeWavePreset == 'home-v2:${p.station}';
                final tracks =
                    stations?.select(widget.music.catalog, p.station) ??
                    <Track>[];
                final enabled =
                    !loading &&
                    !busy &&
                    error == null &&
                    widget.music.ready &&
                    tracks.isNotEmpty;
                return SizedBox(
                  width: 132,
                  child: Opacity(
                    opacity: enabled || busy ? 1 : .5,
                    child: Material(
                      color: Color.alphaBlend(
                        colors[1].withValues(alpha: chosen ? .24 : .12),
                        const Color(0xff242127),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(
                          color: colors[0].withValues(alpha: chosen ? .9 : .20),
                          width: chosen ? 1.5 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: enabled ? () => start(index, tracks) : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 14,
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: colors,
                                  ),
                                ),
                                child: busy && active == index
                                    ? const Padding(
                                        padding: EdgeInsets.all(26),
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        p.icon,
                                        color: Colors.white,
                                        size: 34,
                                      ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                p.name,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                loading
                                    ? '…'
                                    : tracks.isEmpty
                                    ? 'Пока нет треков'
                                    : chosen
                                    ? 'Выбрано'
                                    : p.hint,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors[0],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      );
    },
  );
}
