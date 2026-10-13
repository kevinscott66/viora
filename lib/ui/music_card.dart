import 'mini_player.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../models/music_card.dart';
import '../models/track.dart';
import '../controllers/music_controller.dart';
import '../services/moment_link.dart';
import '../services/social_api.dart';
import 'received_moment.dart';

const cardThemes = {
  'rose': Color(0xff833e5d),
  'ocean': Color(0xff135769),
  'violet': Color(0xff493671),
};

class MusicCardView extends StatelessWidget {
  const MusicCardView({super.key, required this.card, this.onTrack});
  final MusicCard card;
  final void Function(ReceivedMoment)? onTrack;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          cardThemes[card.theme] ?? cardThemes['rose']!,
          const Color(0xff111218),
        ],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'viora / МОЯ МУЗЫКА',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 24),
        Text(
          card.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (card.lyric.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              '«${card.lyric}»',
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
        for (var i = 0; i < card.tracks.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text(
              '0${i + 1}',
              style: const TextStyle(color: Colors.white60, fontSize: 22),
            ),
            title: Text(
              card.tracks[i].title,
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              card.tracks[i].artists.join(' · '),
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: onTrack == null
                ? null
                : const Icon(Icons.play_circle_outline, color: Colors.white),
            onTap: onTrack == null ? null : () => onTrack!(card.tracks[i]),
          ),
      ],
    ),
  );
}

class PublicMusicCardScreen extends StatelessWidget {
  const PublicMusicCardScreen({
    super.key,
    required this.card,
    required this.music,
  });
  final MusicCard card;
  final MusicController music;
  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: MiniPlayer(music: music),
    appBar: AppBar(title: const Text('Музыкальная визитка')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        MusicCardView(
          card: card,
          onTrack: (track) => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ReceivedMomentScreen(moment: track, music: music),
            ),
          ),
        ),
      ],
    ),
  );
}

class MusicCardEditor extends StatefulWidget {
  const MusicCardEditor({super.key, required this.music, this.api});
  final MusicController music;
  final SocialApi? api;
  @override
  State<MusicCardEditor> createState() => _MusicCardEditorState();
}

class _MusicCardEditorState extends State<MusicCardEditor> {
  final name = TextEditingController(), lyric = TextEditingController();
  final tracks = <ReceivedMoment>[];
  String theme = 'rose';
  String? url;
  bool busy = false, loading = true;
  bool unreadable = false;
  SocialApi get api => widget.api ?? SocialApi.instance;
  MusicCard get draft => MusicCard(
    name: name.text.trim(),
    lyric: lyric.text.trim(),
    theme: theme,
    tracks: List.of(tracks),
  );
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    name.dispose();
    lyric.dispose();
    super.dispose();
  }

  void message(Object text) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$text')));
    }
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('musicCardDraft');
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        name.text = data['name'] as String;
        lyric.text = data['lyric'] as String;
        theme = cardThemes.containsKey(data['theme']) ? data['theme'] : 'rose';
        for (final row in data['tracks'] as List) {
          final track = ReceivedMoment.parse(
            Uri(scheme: 'viora', host: 'moment', fragment: jsonEncode(row)),
          );
          if (track == null || tracks.length >= 3) {
            throw const FormatException('Invalid draft');
          }
          tracks.add(track);
        }
      }
      url = prefs.getString('musicCardPublishedUrl');
    } catch (_) {
      unreadable = true;
      message('Не удалось прочитать черновик. Он сохранён без изменений.');
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> saveDraft() async {
    if (unreadable) throw StateError('Повреждённый черновик не перезаписан');
    if (!await (await SharedPreferences.getInstance()).setString(
      'musicCardDraft',
      jsonEncode(draft.toJson()),
    )) {
      throw StateError('Не удалось сохранить черновик');
    }
  }

  Future<void> pick(int slot) async {
    final selected = await showModalBottomSheet<Track>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CardTrackPicker(music: widget.music),
    );
    if (!mounted || selected == null) return;
    final moment = ReceivedMoment(selected.title, selected.artistNames, 0, '');
    if (tracks.asMap().entries.any(
      (e) => e.key != slot && e.value.matches([selected]).isNotEmpty,
    )) {
      message('Этот трек уже выбран');
      return;
    }
    setState(() {
      if (slot < tracks.length) {
        tracks[slot] = moment;
      } else {
        tracks.add(moment);
      }
    });
    try {
      await saveDraft();
    } catch (e) {
      message(e);
    }
  }

  Future<void> action(Future<void> Function() run) async {
    setState(() => busy = true);
    try {
      await run();
    } catch (e) {
      message(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> publish() => action(() async {
    await saveDraft();
    MusicCard checked;
    try {
      checked = MusicCard.fromJson(draft.toJson());
    } catch (_) {
      message('Укажи имя и выбери три разных трека');
      return;
    }
    final result = await api.request('POST', '/api/card', checked.toJson());
    final value = result['url'] as String;
    await (await SharedPreferences.getInstance()).setString(
      'musicCardPublishedUrl',
      value,
    );
    if (mounted) setState(() => url = value);
    message('Визитка опубликована. Теперь можно поделиться ссылкой.');
  });
  Future<void> unpublish() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отключить ссылку?'),
        content: const Text(
          'Визитка перестанет открываться у получателей. Черновик останется.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Отключить'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await action(() async {
      await api.request('POST', '/api/card/unpublish', {});
      await (await SharedPreferences.getInstance()).remove(
        'musicCardPublishedUrl',
      );
      if (mounted) setState(() => url = null);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Музыкальная визитка')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              MusicCardView(
                card: MusicCard(
                  name: name.text.trim().isEmpty
                      ? 'Три трека обо мне'
                      : name.text.trim(),
                  lyric: lyric.text,
                  theme: theme,
                  tracks: tracks,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: name,
                maxLength: 50,
                enabled: !busy && !unreadable,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Имя на визитке'),
              ),
              TextField(
                controller: lyric,
                maxLength: 150,
                maxLines: 3,
                enabled: !busy && !unreadable,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Любимая строка'),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final t in {
                    'rose': 'Роза',
                    'ocean': 'Океан',
                    'violet': 'Сумерки',
                  }.entries)
                    ChoiceChip(
                      label: Text(t.value),
                      selected: theme == t.key,
                      onSelected: busy || unreadable
                          ? null
                          : (_) => setState(() => theme = t.key),
                    ),
                ],
              ),
              for (var i = 0; i < 3; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Text('${i + 1}'),
                  title: Text(
                    i < tracks.length ? tracks[i].title : 'Выбрать трек',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: !busy && !unreadable && i <= tracks.length,
                  onTap: () => pick(i),
                ),
              OutlinedButton(
                onPressed: busy || unreadable
                    ? null
                    : () => action(() async {
                        await saveDraft();
                        message('Черновик сохранён на телефоне');
                      }),
                child: const Text('Сохранить черновик'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Публикация отправит имя, строку и три трека на сервер. Визитку увидит любой, у кого есть ссылка. Аудио и остальная библиотека не отправляются. Правки черновика не меняют опубликованную страницу.',
                ),
              ),
              FilledButton(
                onPressed: busy || unreadable ? null : publish,
                child: Text(
                  busy
                      ? 'Подождите…'
                      : url == null
                      ? 'Опубликовать'
                      : 'Обновить опубликованную визитку',
                ),
              ),
              if (url != null) ...[
                SelectableText(url!),
                Builder(
                  builder: (context) => TextButton.icon(
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Поделиться ссылкой'),
                    onPressed: busy
                        ? null
                        : () => action(() async {
                            final box =
                                context.findRenderObject()! as RenderBox;
                            await SharePlus.instance.share(
                              ShareParams(
                                text: url!,
                                sharePositionOrigin:
                                    box.localToGlobal(Offset.zero) & box.size,
                              ),
                            );
                          }),
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : unpublish,
                  child: const Text('Отключить ссылку'),
                ),
              ],
            ],
          ),
  );
}

class _CardTrackPicker extends StatefulWidget {
  const _CardTrackPicker({required this.music});
  final MusicController music;
  @override
  State<_CardTrackPicker> createState() => _CardTrackPickerState();
}

class _CardTrackPickerState extends State<_CardTrackPicker> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final tracks = widget.music.catalog
        .where(
          (t) => '${t.title} ${t.artist}'.toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Найти трек'),
                onChanged: (s) => setState(() => query = s),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: tracks.length,
                itemBuilder: (context, i) => ListTile(
                  title: Text(tracks[i].title),
                  subtitle: Text(tracks[i].artist),
                  onTap: () => Navigator.pop(context, tracks[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
