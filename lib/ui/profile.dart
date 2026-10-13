import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/music_controller.dart';
import '../services/social_api.dart';
import 'mini_player.dart';
import 'diary.dart';
import 'fragments.dart';
import 'music_card.dart';
import '../services/chat_crypto.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.music, this.api});
  final MusicController music;
  final SocialApi? api;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final api = widget.api ?? SocialApi.instance;
  final name = TextEditingController();
  final bio = TextEditingController();
  String color = 'rose';
  String? error;
  bool loading = true, busy = false, hasRecovery = false;
  List<dynamic> sessions = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    name.dispose();
    bio.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final p = await api.request('GET', '/api/profile');
      final s = await api.request('GET', '/api/sessions');
      if (!mounted) return;
      setState(() {
        name.text = p['name'] as String;
        bio.text = p['bio'] as String? ?? '';
        color = p['color'] as String? ?? 'rose';
        hasRecovery = p['hasKeyRecovery'] == true;
        sessions = s['sessions'] as List;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  Future<void> action(Future<void> Function() f) async {
    setState(() => busy = true);
    try {
      await f();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Продолжить'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> recovery() async {
    if (hasRecovery &&
        !await confirm(
          'Обновить код?',
          'Прежний код перестанет работать. Подключённые устройства останутся в профиле.',
        )) {
      return;
    }
    if (!mounted) return;
    await action(() async {
      final code = await ChatCrypto(api).createRecovery();
      if (!mounted) return;
      setState(() => hasRecovery = true);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: const Text('Сохраните код восстановления'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Этот код даёт доступ к профилю и диалогам. Сохраните в менеджере паролей. Повторно показать его нельзя.',
              ),
              const SizedBox(height: 16),
              SelectableText(code),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: code)),
              child: const Text('Скопировать'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Сохранил'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> restore() async {
    if (!await confirm(
      'Войти в другой профиль?',
      'Здесь появятся его диалоги. Музыка и избранное на телефоне сохранятся. Профили не объединяются. Сохраните код текущего профиля перед переключением.',
    )) {
      return;
    }
    if (!mounted) return;
    var enteredCode = '';
    final code = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Код восстановления'),
        content: TextField(
          onChanged: (value) => enteredCode = value,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, enteredCode),
            child: const Text('Войти'),
          ),
        ],
      ),
    );
    // The dialog route may still be animating out while its TextField is mounted.
    if (code == null || !mounted) return;
    await action(() async {
      await api.recover(code);
      await load();
    });
  }

  Color get accent => switch (color) {
    'ocean' => const Color(0xff79d8cb),
    'dusk' => const Color(0xffbca3ef),
    _ => const Color(0xfff291a0),
  };

  Widget iconBadge(IconData icon) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(icon, color: accent, size: 23),
  );

  Widget quickAction(
    double width,
    IconData icon,
    String label,
    Widget Function() screen,
  ) => SizedBox(
    width: width,
    child: Material(
      color: accent.withValues(alpha: .08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: accent.withValues(alpha: .16)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => screen()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
          child: Column(
            children: [
              iconBadge(icon),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  InputDecoration fieldDecoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: const Color(0xff232226),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.all(18),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Мой профиль'),
      centerTitle: true,
      backgroundColor: const Color(0xff171719),
      scrolledUnderElevation: 0,
    ),
    bottomNavigationBar: MiniPlayer(music: widget.music),
    body: DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(.5, -1),
          radius: 1.2,
          colors: [
            {
              'rose': const Color(0xff39232f),
              'ocean': const Color(0xff173234),
              'dusk': const Color(0xff2b2340),
            }[color]!,
            const Color(0xff171719),
          ],
          stops: const [0, .8],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? Center(
                child: TextButton(
                  onPressed: load,
                  child: Text('$error\nПовторить'),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: .13),
                          const Color(0xff1d1b20),
                        ],
                      ),
                      border: Border.all(color: accent.withValues(alpha: .13)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                {
                                  'rose': const Color(0xffb46782),
                                  'ocean': const Color(0xff3e9b97),
                                  'dusk': const Color(0xff8971be),
                                }[color]!,
                                const Color(0xff37303e),
                              ],
                            ),
                            border: Border.all(color: Colors.white24),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: .12),
                                blurRadius: 28,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ValueListenableBuilder(
                          valueListenable: name,
                          builder: (_, value, child) => Text(
                            value.text.trim().isEmpty
                                ? 'Ваше пространство'
                                : value.text.trim(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              letterSpacing: -.6,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ValueListenableBuilder(
                          valueListenable: bio,
                          builder: (_, value, child) => Text(
                            value.text.trim().isEmpty
                                ? 'Музыка, моменты и ваши люди'
                                : value.text.trim(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ExpansionTile(
                    title: const Text('Изменить профиль'),
                    leading: iconBadge(Icons.edit_outlined),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: const EdgeInsets.all(16),
                    collapsedBackgroundColor: const Color(0xff232226),
                    backgroundColor: const Color(0xff232226),
                    collapsedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    children: [
                      TextField(
                        controller: name,
                        onChanged: (_) => setState(() {}),
                        maxLength: 50,
                        decoration: fieldDecoration('Как вас зовут'),
                      ),
                      TextField(
                        controller: bio,
                        maxLength: 200,
                        minLines: 1,
                        maxLines: 3,
                        decoration: fieldDecoration('Пара слов о себе'),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final entry in {
                            'rose': 'Роза',
                            'ocean': 'Океан',
                            'dusk': 'Сумерки',
                          }.entries)
                            ChoiceChip(
                              label: Text(entry.value),
                              selected: color == entry.key,
                              onSelected: busy
                                  ? null
                                  : (_) => setState(() => color = entry.key),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: busy || name.text.trim().isEmpty
                            ? null
                            : () => action(() async {
                                await api.request('POST', '/api/profile', {
                                  'name': name.text.trim(),
                                  'bio': bio.text,
                                  'color': color,
                                });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Профиль сохранён'),
                                    ),
                                  );
                                }
                              }),
                        child: Text(busy ? 'Сохраняем…' : 'Сохранить профиль'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Моя музыка в деталях',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns =
                          MediaQuery.textScalerOf(context).scale(14) > 20
                          ? 1
                          : 3;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 8) / columns;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          quickAction(
                            width,
                            Icons.auto_stories_outlined,
                            'Моменты',
                            () => DiaryScreen(music: widget.music),
                          ),
                          quickAction(
                            width,
                            Icons.bookmarks_outlined,
                            'Фрагменты',
                            () => FragmentsScreen(music: widget.music),
                          ),
                          quickAction(
                            width,
                            Icons.badge_outlined,
                            'Визитка',
                            () => MusicCardEditor(music: widget.music),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Доступ к профилю',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    tileColor: const Color(0xff232226),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: iconBadge(Icons.key_rounded),
                    title: Text(
                      hasRecovery
                          ? 'Код восстановления создан'
                          : 'Сохранить доступ',
                    ),
                    subtitle: Text(
                      hasRecovery
                          ? 'Заменить код при необходимости'
                          : 'Для входа на другом телефоне',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: busy ? null : recovery,
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    tileColor: const Color(0xff232226),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: iconBadge(Icons.login_rounded),
                    title: const Text('У меня уже есть профиль'),
                    subtitle: const Text('Войти с кодом восстановления'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: busy ? null : restore,
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Устройства',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  for (final s in sessions)
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      tileColor: const Color(0xff232226),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: iconBadge(Icons.phone_iphone_rounded),
                      title: Text(s['label'] as String),
                      subtitle: s['current'] == true
                          ? Text(
                              'Это устройство',
                              style: TextStyle(color: accent),
                            )
                          : null,
                      trailing: s['current'] == true
                          ? null
                          : IconButton(
                              tooltip: 'Отключить устройство',
                              icon: const Icon(Icons.logout),
                              onPressed: busy
                                  ? null
                                  : () async {
                                      if (await confirm(
                                        'Отключить устройство?',
                                        'На нём прекратится доступ к диалогам.',
                                      )) {
                                        await action(() async {
                                          await api.request(
                                            'POST',
                                            '/api/sessions/revoke',
                                            {'id': s['id']},
                                          );
                                          await load();
                                        });
                                      }
                                    },
                            ),
                    ),
                ],
              ),
      ),
    ),
  );
}
