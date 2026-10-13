import 'fragments.dart';
import 'diary.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import '../services/social_api.dart';
import 'chats.dart';
import 'package:flutter/foundation.dart';
import '../services/moment_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import '../models/track.dart';
import '../services/moment_link.dart';
import 'moment_card.dart';

/// Captures the selected song and time, independently of subsequent playback.
class MomentComposer extends StatefulWidget {
  const MomentComposer({
    super.key,
    required this.track,
    required this.position,
    required this.duration,
    this.initialLyric = '',
    this.replyTo,
    this.chatId,
  });
  final String initialLyric;
  final ReceivedMoment? replyTo;
  final String? chatId;
  final Track track;
  final Duration position, duration;
  @override
  State<MomentComposer> createState() => _MomentComposerState();
}

class _MomentComposerState extends State<MomentComposer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2880),
  );
  bool _animated = false;
  double? _exportPhase;
  int _frame = 0;
  final _card = GlobalKey();
  final _note = TextEditingController();
  late final _lyric = TextEditingController(
    text: widget.initialLyric.characters.take(150).toString(),
  );
  late double _seconds;
  bool _sharing = false;
  double get _max => widget.duration.inSeconds.toDouble().clamp(0, 86400);
  @override
  void initState() {
    super.initState();
    _seconds = widget.position.inSeconds.toDouble().clamp(0, _max);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _motion.stop();
    } else if (_animated && !_sharing) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    _note.dispose();
    _lyric.dispose();
    super.dispose();
  }

  void _setAnimated(bool value) {
    setState(() => _animated = value);
    if (value && !MediaQuery.of(context).disableAnimations) {
      _motion.repeat();
    } else {
      _motion.stop();
    }
  }

  Future<void> _share() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _sharing = true);
    try {
      await Scrollable.ensureVisible(_card.currentContext!, alignment: 0);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final boundary =
          _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final origin = boundary.localToGlobal(Offset.zero) & boundary.size;
      Uint8List bytes;
      if (_animated) {
        _motion.stop();
        final frames = <Uint8List>[];
        for (var i = 0; i < 24; i++) {
          if (!mounted) return;
          setState(() {
            _exportPhase = i / 24;
            _frame = i + 1;
          });
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted) return;
          final image = await boundary.toImage(
            pixelRatio: 480 / boundary.size.width,
          );
          try {
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            if (data == null) throw StateError('Frame unavailable');
            frames.add(data.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        }
        bytes = await compute(encodeMomentAnimation, frames);
      } else {
        final image = await boundary.toImage(pixelRatio: 3);
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          if (data == null) throw StateError('Card image unavailable');
          bytes = data.buffer.asUint8List();
        } finally {
          image.dispose();
        }
      }
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          title: 'Лови момент · ${widget.track.title}',
          files: [
            XFile.fromData(
              bytes,
              mimeType: _animated ? 'image/gif' : 'image/png',
            ),
          ],
          fileNameOverrides: [
            _animated ? 'viora-moment.gif' : 'viora-moment.png',
          ],
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось подготовить карточку. Попробуйте ещё раз.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sharing = false;
          _exportPhase = null;
          _frame = 0;
        });
        if (_animated && !MediaQuery.of(context).disableAnimations) {
          _motion.repeat();
        }
      }
    }
  }

  Future<void> _shareLink(BuildContext buttonContext) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final box = buttonContext.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() => _sharing = true);
    try {
      final link = momentLink(
        widget.track,
        Duration(seconds: _seconds.round()),
        _note.text,
        lyric: _lyric.text,
        replyTo: widget.replyTo,
      );
      final shortLink = await SocialApi.instance.shorten(link);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          title: 'Лови момент · ${widget.track.title}',
          text: shortLink.toString(),
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось отправить ссылку. Попробуйте ещё раз.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _sendChat() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _sharing = true);
    try {
      final link = momentLink(
        widget.track,
        Duration(seconds: _seconds.round()),
        _note.text,
        lyric: _lyric.text,
        replyTo: widget.replyTo,
      );
      await sendMomentToChat(
        context,
        jsonDecode(Uri.decodeComponent(link.fragment)) as Map<String, dynamic>,
        chatId: widget.chatId,
      );
    } catch (e) {
      if (mounted) socialError(context, e);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.replyTo == null ? 'Лови момент' : 'Ответить моментом'),
      actions: [
        IconButton(
          tooltip: 'Сохранить момент',
          icon: const Icon(Icons.bookmark_add_outlined),
          onPressed: _sharing
              ? null
              : () async {
                  final target = await showModalBottomSheet<String>(
                    context: context,
                    builder: (context) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.auto_stories_outlined),
                            title: const Text('В дневник музыки'),
                            onTap: () => Navigator.pop(context, 'diary'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.bookmarks_outlined),
                            title: const Text('В любимые секунды'),
                            enabled: widget.track.durationMs > 0,
                            onTap: () => Navigator.pop(context, 'fragment'),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (!context.mounted || target == null) return;
                  if (target == 'fragment') {
                    await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FragmentEditor(
                          track: widget.track,
                          position: Duration(seconds: _seconds.round()),
                        ),
                      ),
                    );
                    return;
                  }
                  final saved = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DiaryEditor(
                        moment: ReceivedMoment(
                          widget.track.title,
                          widget.track.artistNames,
                          _seconds.round(),
                          _note.text,
                          lyric: _lyric.text,
                        ),
                      ),
                    ),
                  );
                  if (saved == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Момент сохранён в дневнике'),
                      ),
                    );
                  }
                },
        ),
      ],
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: _sharing ? null : _sendChat,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('В диалог'),
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.image_outlined),
                      label: Text('Фото'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.auto_awesome),
                      label: Text('Живая'),
                    ),
                  ],
                  selected: {_animated},
                  onSelectionChanged: _sharing
                      ? null
                      : (values) => _setAnimated(values.single),
                ),
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: _motion,
                  builder: (context, _) => RepaintBoundary(
                    key: _card,
                    child: MomentCard(
                      track: widget.track,
                      position: Duration(seconds: _seconds.round()),
                      lyric: _lyric.text,
                      note: _note.text,
                      phase: _exportPhase ?? (_animated ? _motion.value : 0),
                      replyTo: widget.replyTo,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Начать с ${formatTime(Duration(seconds: _seconds.round()))}',
                ),
                Slider(
                  value: _seconds,
                  max: _max > 0 ? _max : 1,
                  onChanged: _sharing || _max == 0
                      ? null
                      : (value) => setState(() => _seconds = value),
                ),
                TextField(
                  controller: _lyric,
                  maxLength: 150,
                  maxLines: 2,
                  enabled: !_sharing,
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Строки песни',
                    hintText: 'Проверь распознанные слова',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  maxLength: 100,
                  maxLines: 2,
                  enabled: !_sharing,
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Почему именно этот момент?',
                    hintText: 'Этот припев — про нас',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _sharing ? null : _share,
                  icon: Icon(_sharing ? Icons.hourglass_top : Icons.ios_share),
                  label: Text(
                    _sharing
                        ? (_frame > 0
                              ? 'Готовим анимацию… $_frame/24'
                              : 'Готовим карточку…')
                        : 'Поделиться карточкой',
                  ),
                ),
                Builder(
                  builder: (buttonContext) => TextButton.icon(
                    onPressed: _sharing
                        ? null
                        : () => _shareLink(buttonContext),
                    icon: const Icon(Icons.link),
                    label: const Text('Поделиться ссылкой'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _animated
                      ? 'Зацикленная GIF-открытка без звука. Ссылка для прослушивания и ответа отправляется отдельно.'
                      : 'Карточка отправляется одним изображением. Ссылка на момент — отдельно, по вашему выбору.',
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
