import 'mini_player.dart';
import '../services/diary_repository.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:share_plus/share_plus.dart';
import '../controllers/music_controller.dart';
import '../models/diary_entry.dart';
import '../services/diary_store.dart';
import '../services/moment_link.dart';
import 'received_moment.dart';

String diaryDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
String diaryPhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Unsupported image');
  final oriented = img.bakeOrientation(decoded);
  final resized = oriented.width > 1200 || oriented.height > 1200
      ? img.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? 1200 : null,
          height: oriented.height > oriented.width ? 1200 : null,
        )
      : oriented;
  return base64Encode(img.encodeJpg(resized, quality: 85));
}

class DiaryEditor extends StatefulWidget {
  const DiaryEditor({super.key, required this.moment, this.entry, this.store});
  final ReceivedMoment moment;
  final DiaryEntry? entry;
  final DiaryRepository? store;
  @override
  State<DiaryEditor> createState() => _DiaryEditorState();
}

class _DiaryEditorState extends State<DiaryEditor> {
  late final note = TextEditingController(
    text: widget.entry?.note ?? widget.moment.note,
  );
  late DateTime date = widget.entry?.date ?? DateTime.now();
  late String? photo = widget.entry?.photo;
  bool busy = false;
  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  void error(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> pick() async {
    setState(() => busy = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );
      if (result.isEmpty) return;
      final file = result.single;
      final size = await file.length();
      if (size == null || size > 15 * 1024 * 1024) {
        throw const FormatException();
      }
      final value = await compute(diaryPhoto, await file.readAsBytes());
      if (mounted) setState(() => photo = value);
    } catch (_) {
      error('Не удалось открыть фото. Выберите JPG или PNG до 15 МБ.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      await (widget.store ?? DiaryStore()).save(
        DiaryEntry(
          id:
              widget.entry?.id ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          date: date,
          moment: widget.moment,
          note: note.text.trim(),
          photo: photo,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      error('Не удалось сохранить. Запись остаётся открытой.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('В дневник')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          widget.moment.title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(widget.moment.artists.join(' · ')),
        if (widget.moment.lyric.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              widget.moment.lyric,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        TextButton.icon(
          onPressed: busy
              ? null
              : () async {
                  final value = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (value != null && mounted) setState(() => date = value);
                },
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(diaryDate(date)),
        ),
        TextField(
          controller: note,
          maxLength: 2000,
          minLines: 3,
          maxLines: 8,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: 'Что хочется запомнить?',
            border: OutlineInputBorder(),
          ),
        ),
        if (photo != null) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.memory(
              base64Decode(photo!),
              height: 240,
              fit: BoxFit.cover,
            ),
          ),
          TextButton(
            onPressed: busy ? null : () => setState(() => photo = null),
            child: const Text('Убрать фото'),
          ),
        ],
        OutlinedButton.icon(
          onPressed: busy ? null : pick,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(photo == null ? 'Добавить фото' : 'Заменить фото'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? 'Сохраняем…' : 'Сохранить в дневник'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Только на этом устройстве. Заметка и фото не отправляются в диалоги или на сервер.',
          style: TextStyle(color: Colors.white54),
        ),
      ],
    ),
  );
}

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key, required this.music, this.store});
  final MusicController music;
  final DiaryRepository? store;
  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  late final store = widget.store ?? DiaryStore();
  List<DiaryEntry> entries = [];
  String query = '';
  DateTime? day;
  bool loading = true;
  bool failed = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await store.load();
      if (mounted) {
        setState(() {
          entries = result;
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

  Future<void> edit(DiaryEntry e) async {
    await Navigator.push(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => DiaryEditor(moment: e.moment, entry: e, store: store),
      ),
    );
    await load();
  }

  Future<void> remove(DiaryEntry e) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить момент?'),
        content: const Text(
          'Заметка и фото будут удалены из дневника. Трек останется в библиотеке.',
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
    if (yes != true) return;
    try {
      await store.delete(e);
      await load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось удалить запись')),
        );
      }
    }
  }

  Future<void> export(BuildContext anchor) async {
    try {
      final box = anchor.findRenderObject()! as RenderBox;
      await SharePlus.instance.share(
        ShareParams(
          title: 'Дневник viora',
          files: [
            XFile.fromData(
              Uint8List.fromList(
                utf8.encode(
                  jsonEncode({
                    'version': 1,
                    'entries': entries.map((e) => e.toJson()).toList(),
                  }),
                ),
              ),
              mimeType: 'application/json',
            ),
          ],
          fileNameOverrides: ['viora-diary.json'],
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось экспортировать дневник')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = entries.where((e) => e.matches(query, day)).toList();
    return Scaffold(
      bottomNavigationBar: MiniPlayer(music: widget.music),
      appBar: AppBar(
        title: const Text('Дневник музыки'),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              tooltip: 'Экспорт дневника',
              onPressed: entries.isEmpty || failed ? null : () => export(ctx),
              icon: const Icon(Icons.ios_share),
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : failed
          ? Center(
              child: TextButton(
                onPressed: load,
                child: const Text('Не удалось прочитать дневник. Повторить'),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: TextField(
                    onChanged: (v) => setState(() => query = v),
                    decoration: const InputDecoration(
                      hintText: 'Трек, строки или заметка',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        day == null ? 'Выбрать день' : diaryDate(day!),
                      ),
                      onPressed: () async {
                        final selected = await showDatePicker(
                          context: context,
                          initialDate: day ?? DateTime.now(),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (selected != null && mounted) {
                          setState(() => day = selected);
                        }
                      },
                    ),
                    if (day != null)
                      IconButton(
                        tooltip: 'Все даты',
                        onPressed: () => setState(() => day = null),
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
                Expanded(
                  child: visible.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              entries.isEmpty
                                  ? 'Сохрани первый момент из плеера: «Лови момент» → значок дневника.\n\nЗдесь он останется только для тебя.'
                                  : 'В этот день или по этому запросу записей нет.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: visible.length,
                          itemBuilder: (context, i) {
                            final e = visible[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            diaryDate(e.date),
                                            style: const TextStyle(
                                              color: Colors.white60,
                                            ),
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          onSelected: (v) =>
                                              v == 'edit' ? edit(e) : remove(e),
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Изменить'),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Удалить'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Text(
                                      e.moment.title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    Text(e.moment.artists.join(' · ')),
                                    if (e.moment.lyric.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        child: Text(
                                          e.moment.lyric,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                      ),
                                    if (e.photo != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Image.memory(
                                          base64Decode(e.photo!),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, error, stack) =>
                                              const Text('Фото недоступно'),
                                        ),
                                      ),
                                    if (e.note.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Text(e.note),
                                      ),
                                    TextButton.icon(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) => ReceivedMomentScreen(
                                            moment: e.moment,
                                            music: widget.music,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(Icons.play_arrow),
                                      label: Text(
                                        'Открыть момент · ${e.moment.seconds ~/ 60}:${(e.moment.seconds % 60).toString().padLeft(2, '0')}',
                                      ),
                                    ),
                                  ],
                                ),
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
