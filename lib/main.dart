import 'models/music_card.dart';
import 'ui/music_card.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'services/social_api.dart';
import 'ui/chats.dart';
import 'ui/received_moment.dart';
import 'ui/moment_reply.dart';
import 'dart:ui';
import 'services/diagnostics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'controllers/music_controller.dart';
import 'services/background_audio.dart';
import 'ui/library.dart';
import 'ui/shared.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Diagnostics.initialize();
  FlutterError.onError = (details) {
    Diagnostics.record('error.flutter', {
      'error': details.exceptionAsString(),
      'stack': details.stack.toString(),
    });
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    Diagnostics.record('error.unhandled', {
      'error': error.toString(),
      'stack': stack.toString(),
    });
    return false;
  };
  await initializeBackgroundAudio();
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
  );
  runApp(const SpunApp());
}

class SpunApp extends StatefulWidget {
  const SpunApp({super.key});
  @override
  State<SpunApp> createState() => _SpunAppState();
}

class _SpunAppState extends State<SpunApp> with WidgetsBindingObserver {
  late final MusicController music;
  final _navigation = _DiagnosticNavigation();
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _links;
  final _appLinks = AppLinks();
  Future<void> _openMoment(Uri uri) async {
    if (uri.scheme == 'viora' &&
        uri.host == 'chat' &&
        uri.queryParameters['invite'] != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _navigatorKey.currentState?.push(
            MaterialPageRoute<void>(
              builder: (_) => ChatsScreen(music: music, invite: uri.toString()),
            ),
          );
        }
      });
      WidgetsBinding.instance.ensureVisualUpdate();
      return;
    }
    try {
      final cardId = uri.scheme == 'viora' && uri.host == 'card'
          ? uri.queryParameters['id']
          : uri.scheme == 'https' &&
                uri.host == 'viora.example.com' &&
                uri.pathSegments.length == 2 &&
                uri.pathSegments.first == 'p'
          ? uri.pathSegments.last
          : null;
      if (cardId != null && RegExp(r'^[A-Za-z0-9_-]{16}$').hasMatch(cardId)) {
        final data = await SocialApi.instance.request(
          'GET',
          '/api/cards/$cardId',
          null,
          false,
        );
        final card = MusicCard.fromJson(data);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _navigatorKey.currentState?.push(
              MaterialPageRoute<void>(
                builder: (_) => PublicMusicCardScreen(card: card, music: music),
              ),
            );
          }
        });
        WidgetsBinding.instance.ensureVisualUpdate();
        return;
      }
      final moment = await SocialApi.instance.resolve(uri);
      if (moment == null) {
        Diagnostics.record('moment.link.invalid');
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Diagnostics.record('moment.link.received', {'seconds': moment.seconds});
        _navigatorKey.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => uri.queryParameters['reply'] == '1'
                ? MomentReplyScreen(music: music, parent: moment)
                : ReceivedMomentScreen(moment: moment, music: music),
          ),
        );
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    } catch (e) {
      final context = _navigatorKey.currentContext;
      if (context != null && context.mounted) socialError(context, e);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    music = MusicController();
    unawaited(music.initialize());
    _links = _appLinks.uriLinkStream.listen(
      _openMoment,
      onError: (_) => Diagnostics.record('moment.link.error'),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_links?.cancel());
    music.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    Diagnostics.record('app.lifecycle', {'state': state.name});
    unawaited(music.savePlayback());
    unawaited(Diagnostics.flush());
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'viora — Feel every beat',
    navigatorKey: _navigatorKey,
    builder: (context, child) => Listener(
      onPointerDown: (e) => Diagnostics.record('ui.pointer', {
        'x': e.position.dx.round(),
        'y': e.position.dy.round(),
      }),
      child: child!,
    ),
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xff171719),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xfff291a0),
        surface: Color(0xff232326),
      ),
      fontFamily: 'SpunSans',
      useMaterial3: true,
      splashFactory: InkSparkle.splashFactory,
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: Colors.white,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xff202023),
        indicatorColor: const Color(0xff443139),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? const Color(0xfff291a0)
                : Colors.white70,
          ),
        ),
      ),
    ),
    navigatorObservers: [_navigation],
    home: EntryScreen(music: music),
  );
}

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key, required this.music});
  final MusicController music;
  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  bool entered = false;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer(const Duration(milliseconds: 2400), enter);
  }

  void enter() {
    if (mounted && !entered) setState(() => entered = true);
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: motion(context, 600),
    child: entered
        ? LibraryScreen(music: widget.music)
        : Scaffold(
            key: const ValueKey('splash'),
            body: GestureDetector(
              onTap: enter,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -.35),
                    radius: 1.1,
                    colors: [
                      Color(0xffb81e37),
                      Color(0xff520f22),
                      Color(0xff160d14),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      const Spacer(flex: 3),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: motion(context, 1100),
                        builder: (context, v, child) => Opacity(
                          opacity: v,
                          child: Transform.translate(
                            offset: Offset(0, 24 * (1 - v)),
                            child: child,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(44),
                          child: Image.asset(
                            'assets/branding/viora-logo.png',
                            width: 200,
                            height: 200,
                          ),
                        ),
                      ),
                      const SizedBox(height: 34),
                      const Text(
                        'viora',
                        style: TextStyle(
                          fontSize: 58,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -3,
                        ),
                      ),
                      const Text(
                        'Feel every beat.',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontStyle: FontStyle.italic,
                          fontSize: 20,
                          color: Color(0xffeed3d8),
                        ),
                      ),
                      const Spacer(flex: 4),
                      TextButton(
                        onPressed: enter,
                        child: const Text(
                          'Открыть библиотеку',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 24),
                        child: Text(
                          'MUSIC IS A FEELING',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 3,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
  );
}

class _DiagnosticNavigation extends NavigatorObserver {
  String? name(Route<dynamic>? route) =>
      route?.settings.name ?? route?.runtimeType.toString();
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      Diagnostics.record('ui.route.push', {
        'route': name(route),
        'previous': name(previousRoute),
      });
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      Diagnostics.record('ui.route.pop', {
        'route': name(route),
        'destination': name(previousRoute),
      });
}
