import 'profile.dart';
import '../controllers/chat_controller.dart';
import 'chat_security.dart';
import '../services/chat_crypto.dart';
import 'mini_player.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/music_controller.dart';
import '../services/social_api.dart';
import '../services/moment_link.dart';
import 'chat_moment_card.dart';
import 'moment_reply.dart';

void socialError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      content: Text(error.toString()),
    ),
  );
}

Future<String?> textPrompt(
  BuildContext context,
  String title, {
  String initial = '',
}) async {
  final input = TextEditingController(text: initial);
  final value = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: input,
        autofocus: true,
        maxLength: title == 'Ваше имя' ? 50 : 300,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, input.text.trim()),
          child: const Text('Продолжить'),
        ),
      ],
    ),
  );
  // The dialog exit animation can still reference the controller.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  input.dispose();
  return value;
}

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key, required this.music, this.invite});
  final MusicController music;
  final String? invite;
  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  List<dynamic>? rooms;
  String? error;
  bool busy = false;
  String query = "";
  final api = SocialApi.instance;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await api.request('GET', '/api/chats');
      if (mounted) {
        setState(() {
          rooms = data['chats'] as List;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> create() async {
    setState(() => busy = true);
    try {
      final room = await api.request('POST', '/api/chats', {});
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Пригласить в диалог'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ссылка для одного собеседника. Действует 7 дней. Скопируйте её перед закрытием.',
              ),
              const SizedBox(height: 16),
              SelectableText(room['invite'] as String),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: room['invite'] as String),
                );
                if (c.mounted) Navigator.pop(c);
              },
              child: const Text('Скопировать'),
            ),
          ],
        ),
      );
      await load();
    } catch (e) {
      if (mounted) socialError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> join() async {
    final value = await textPrompt(
      context,
      'Ссылка-приглашение',
      initial: widget.invite ?? '',
    );
    if (value == null || value.isEmpty || !mounted) return;
    final uri = Uri.tryParse(value);
    final code = uri?.scheme == 'viora' && uri?.host == 'chat'
        ? uri?.queryParameters['invite']
        : uri?.scheme == 'https' &&
              uri?.host == 'viora.example.com' &&
              uri?.pathSegments.length == 2 &&
              uri?.pathSegments.first == 'c'
        ? uri?.pathSegments.last
        : value;
    setState(() => busy = true);
    try {
      await api.request('POST', '/api/join', {'invite': code});
      await load();
    } catch (e) {
      if (mounted) socialError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> rename() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(music: widget.music),
      ),
    );
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Диалоги'),
      actions: [
        IconButton(
          onPressed: rename,
          tooltip: 'Мой профиль',
          icon: const Icon(Icons.person_outline),
        ),
      ],
    ),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Ваши люди. Ваша музыка. Делитесь моментами и отвечайте песнями.',
          ),
        ),
        Wrap(
          spacing: 12,
          children: [
            FilledButton.icon(
              onPressed: busy ? null : create,
              icon: const Icon(Icons.add),
              label: const Text('Пригласить'),
            ),
            OutlinedButton(
              onPressed: busy ? null : join,
              child: const Text('Войти по ссылке'),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            onChanged: (value) =>
                setState(() => query = value.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Найти диалог',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (widget.invite != null)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Приглашение получено. Нажмите «Войти по ссылке».'),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(error!),
                TextButton(onPressed: load, child: const Text('Повторить')),
              ],
            ),
          ),
        Expanded(
          child: rooms == null
              ? (error == null
                    ? const Center(child: CircularProgressIndicator())
                    : const SizedBox())
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (rooms!.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Первый разговор начинается с любимой песни. Пригласите друга.',
                          ),
                        ),
                      if (rooms!.isNotEmpty &&
                          !rooms!.any(
                            (r) => (r['name'] as String? ?? 'Ждём собеседника')
                                .toLowerCase()
                                .contains(query),
                          ))
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Диалоги не найдены'),
                        ),
                      for (final r in rooms!.where(
                        (r) => (r['name'] as String? ?? 'Ждём собеседника')
                            .toLowerCase()
                            .contains(query),
                      ))
                        ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.chat_bubble_outline),
                          ),
                          title: Text(
                            r['name'] as String? ?? 'Ждём собеседника',
                          ),
                          subtitle: Text(
                            r['waiting'] == 1
                                ? 'Приглашение отправляется по ссылке'
                                : 'Музыкальный диалог',
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => ChatScreen(
                                  id: r['id'] as String,
                                  name: r['name'] as String? ?? 'Диалог',
                                  music: widget.music,
                                ),
                              ),
                            );
                            await load();
                          },
                        ),
                    ],
                  ),
                ),
        ),
      ],
    ),
  );
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.id,
    required this.name,
    required this.music,
    this.api,
  });
  final String id, name;
  final MusicController music;
  final SocialApi? api;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final input = TextEditingController();
  late final SocialApi api;
  final scroll = ScrollController();
  late final ChatController chat;
  List<dynamic> get messages => chat.messages;
  bool get sending => chat.sending;
  bool get hasOlder => chat.hasOlder;
  String? get error => chat.error;
  Timer? timer;
  bool active = true;
  bool needsRecovery = false;
  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    api = widget.api ?? SocialApi.instance;
    chat = ChatController.forRoom(widget.id, api)..addListener(changed);
    WidgetsBinding.instance.addObserver(this);
    prepare();
    load();
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (active) load();
    });
  }

  Future<void> prepare() async {
    try {
      await ChatCrypto(api).ensureIdentity();
      final p = await api.request('GET', '/api/profile');
      if (mounted) setState(() => needsRecovery = p['hasKeyRecovery'] != true);
    } catch (e) {
      if (mounted) socialError(context, e);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (active) load();
  }

  @override
  void dispose() {
    timer?.cancel();
    chat.removeListener(changed);
    chat.dispose();
    WidgetsBinding.instance.removeObserver(this);
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> load({bool older = false}) async {
    final nearBottom = !scroll.hasClients || scroll.position.extentAfter < 120;
    final oldMax = scroll.hasClients ? scroll.position.maxScrollExtent : 0.0;
    final oldOffset = scroll.hasClients ? scroll.offset : 0.0;
    final previousMessages = chat.messages;
    await chat.load(older: older);
    if (!mounted || identical(previousMessages, chat.messages)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;
      if (older) {
        scroll.jumpTo(
          (oldOffset + scroll.position.maxScrollExtent - oldMax).clamp(
            0.0,
            scroll.position.maxScrollExtent,
          ),
        );
      } else if (nearBottom) {
        scroll.jumpTo(scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> send() async {
    final text = input.text.trim();
    if (text.isEmpty || sending) return;
    try {
      await chat.send(text);
      if (!mounted) return;
      if (input.text.trim() == text) input.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients) {
          scroll.jumpTo(scroll.position.maxScrollExtent);
        }
      });
    } catch (e) {
      if (mounted) socialError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: MiniPlayer(music: widget.music),
    appBar: AppBar(
      title: Text(widget.name),
      actions: [
        IconButton(
          tooltip: 'О диалоге',
          onPressed: () => showChatSecurity(context, widget.id),
          icon: const Icon(Icons.info_outline_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Поймай момент. Ответь своей песней.',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          if (needsRecovery)
            ListTile(
              dense: true,
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Сохраните доступ к переписке'),
              subtitle: const Text(
                'Старый код не восстановит новые сообщения. Нужен новый код в профиле.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ProfileScreen(music: widget.music),
                  ),
                );
                if (mounted) await prepare();
              },
            ),
          if (error != null)
            TextButton(onPressed: load, child: Text('$error Повторить')),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return hasOlder && messages.isNotEmpty
                      ? TextButton(
                          onPressed: chat.loadingOlder
                              ? null
                              : () => load(older: true),
                          child: Text(
                            chat.loadingOlder
                                ? 'Загружаем…'
                                : 'Ранние сообщения',
                          ),
                        )
                      : const SizedBox();
                }
                final m = messages[i - 1];
                final moment = m['moment'] == null
                    ? null
                    : ReceivedMoment.parse(
                        Uri(
                          scheme: 'viora',
                          host: 'moment',
                          fragment: jsonEncode(m['moment']),
                        ),
                      );
                return Align(
                  alignment: m['mine'] == true
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 360),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: moment == null
                        ? const EdgeInsets.all(14)
                        : EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: m['mine'] == true
                          ? const Color(0xff54333e)
                          : Colors.white10,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((m['text'] as String).isNotEmpty)
                          GestureDetector(
                            onLongPress: () => showMessageActions(
                              context,
                              m['text'] as String,
                            ),
                            child: Text(m['text'] as String),
                          ),
                        if (moment != null)
                          ChatMomentCard(
                            moment: moment,
                            music: widget.music,
                            chatId: widget.id,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Отправить песню',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => MomentReplyScreen(
                        music: widget.music,
                        chatId: widget.id,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add_circle_outline),
                ),
                Expanded(
                  child: TextField(
                    controller: input,
                    enabled: !sending,
                    maxLength: 2000,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Сообщение',
                      counterText: '',
                      filled: true,
                      fillColor: Color(0xff252329),
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: sending ? null : send,
                  icon: Icon(
                    sending ? Icons.hourglass_top : Icons.send_rounded,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> sendMomentToChat(
  BuildContext context,
  Map<String, dynamic> moment, {
  String? chatId,
}) async {
  final api = SocialApi.instance;
  final data = chatId == null
      ? await api.request('GET', '/api/chats')
      : {
          'chats': [
            {'id': chatId},
          ],
        };
  if (!context.mounted) return;
  final rooms = data['chats'] as List;
  if (rooms.isEmpty) {
    socialError(context, 'Сначала создайте диалог на вкладке «Диалоги».');
    return;
  }
  final room =
      chatId ??
      await showModalBottomSheet<String>(
        context: context,
        builder: (c) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Отправить момент')),
              for (final r in rooms)
                ListTile(
                  title: Text(r['name'] as String? ?? 'Ждём собеседника'),
                  onTap: () => Navigator.pop(c, r['id'] as String),
                ),
            ],
          ),
        ),
      );
  if (room == null || !context.mounted) return;
  // Same key is retained across explicit retries after an uncertain response.
  final nonce = SocialApi.nonce();
  while (context.mounted) {
    try {
      await ChatCrypto(
        api,
      ).send(room, {'nonce': nonce, 'text': '', 'moment': moment});
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Момент отправлен')));
      }
      return;
    } catch (e) {
      if (!context.mounted) return;
      final retry = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Не удалось отправить'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Закрыть'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
      if (retry != true) return;
    }
  }
}

Future<void> showMessageActions(BuildContext context, String text) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(text),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Скопировать текст'),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (sheet.mounted) Navigator.pop(sheet);
                },
              ),
            ],
          ),
        ),
      ),
    );
