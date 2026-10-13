import 'package:flutter/material.dart';
import '../services/chat_crypto.dart';
import '../services/social_api.dart';

Future<void> showChatSecurity(BuildContext context, String room) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ChatSecurity(room: room),
    );

class ChatSecurity extends StatefulWidget {
  const ChatSecurity({super.key, required this.room});
  final String room;
  @override
  State<ChatSecurity> createState() => _ChatSecurityState();
}

class _ChatSecurityState extends State<ChatSecurity> {
  String? fingerprint, error;
  bool busy = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final s = await ChatCrypto(SocialApi.instance).status(widget.room);
      final verified = await ChatCipher.fingerprint(s['localKey'] as List<int>);
      if (mounted) setState(() => fingerprint = verified);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff403042), Color(0xff203b3c)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 34,
                  color: Color(0xffeeb0c4),
                ),
                const SizedBox(height: 16),
                Text(
                  busy
                      ? 'Проверяем защиту…'
                      : error != null
                      ? 'Нужно немного внимания'
                      : 'Личное остаётся личным',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  error ??
                      'Новые сообщения и музыкальные моменты шифруются на устройстве перед отправкой. Настраивать ничего не нужно.',
                  style: const TextStyle(height: 1.5, color: Colors.white70),
                ),
              ],
            ),
          ),
          if (error != null)
            TextButton(
              onPressed: busy ? null : load,
              child: const Text('Проверить ещё раз'),
            ),
          const SizedBox(height: 16),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.restore_rounded),
            title: Text('Один код для восстановления'),
            subtitle: Text(
              'Сохраните его в профиле, чтобы перенести переписку на другой телефон.',
            ),
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Подробнее о защите'),
            children: [
              const Text(
                'Старые сообщения, отправленные до обновления, остаются в прежнем формате. Новые отправляются только с шифрованием. Публичные ссылки на моменты доступны всем, у кого есть ссылка.',
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
              if (fingerprint != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Для дополнительной проверки сравните этот номер с собеседником лично или по другому доверенному каналу.',
                ),
                const SizedBox(height: 10),
                SelectableText(
                  RegExp(
                    r'.{1,8}',
                  ).allMatches(fingerprint!).map((m) => m.group(0)).join(' '),
                  style: const TextStyle(fontFamily: 'monospace', height: 1.8),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}
