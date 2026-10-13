import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../services/playback_resume.dart';
import '../services/diagnostics.dart';
import 'package:file_picker/file_picker.dart';
import '../services/music_store.dart';
import '../services/background_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import '../models/favorite_fragment.dart';
import '../models/artist.dart';

class MusicController extends ChangeNotifier {
  MusicController({AudioPlayer? audioPlayer, Random? random})
    : _random = random ?? Random(),
      player = audioPlayer ?? AudioPlayer() {
    _subscriptions.add(
      player.sequenceStateStream.listen((state) {
        final tag = state.currentSource?.tag;
        trace('player.sequence', {
          'actualSourceId': tag is MediaItem ? tag.id : null,
          'actualSourceTitle': tag is MediaItem ? tag.title : null,
          'actualIndex': state.currentIndex,
          'effectiveOrder': player.effectiveIndices,
        });
        _update();
      }),
    );
    _subscriptions.add(
      player.playerStateStream.listen((_) {
        trace('player.state');
        if (!player.playing) unawaited(savePlayback());
        _update();
      }),
    );
    _subscriptions.add(
      player.positionStream.listen((_) {
        if (!_disposed) playbackProgress.notifyListeners();
      }),
    );
    _subscriptions.add(
      player.currentIndexStream.listen((value) {
        trace('player.index', {'receivedIndex': value});
        if (value != null && value != index) {
          transitionDirection = _requestedDirection ?? 1;
          _requestedDirection = null;
        }
        if (value != null) index = value;
        _update();
      }),
    );
    _subscriptions.add(
      player.errorStream.listen((e) {
        trace('error.player', {'error': e.toString()});
        debugPrint('Spun player error: $e');
        error = 'Не удалось воспроизвести аудио. Попробуйте ещё раз.';
        _update();
      }),
    );
  }
  final ChangeNotifier playbackProgress = ChangeNotifier();
  int transitionDirection = 1;
  int? _requestedDirection;
  Future<void> _resumeWrite = Future.value();
  void _startPlayback() {
    unawaited(
      player.play().catchError((Object e, StackTrace stack) {
        trace('error.play', {'error': e.toString()});
        error = 'Ошибка воспроизведения. Попробуйте ещё раз.';
        _update();
      }),
    );
  }

  Future<void> savePlayback() {
    if (!ready ||
        loading ||
        _pendingActions > 0 ||
        queue.isEmpty ||
        _prefs == null ||
        player.processingState == ProcessingState.loading ||
        player.processingState == ProcessingState.buffering) {
      return Future.value();
    }
    final actual = player.currentIndex;
    if (actual == null || actual < 0 || actual >= queue.length) {
      return Future.value();
    }
    final value = jsonEncode({
      'queue': queue.map((t) => t.id).toList(),
      'track': queue[actual].id,
      'positionMs': player.processingState == ProcessingState.completed
          ? (fragment?.startMs ?? 0)
          : position.inMilliseconds,
      'shuffle': shuffled,
      'repeat': repeat.name,
    });
    _resumeWrite = _resumeWrite.then((_) async {
      try {
        await _prefs!.setString('playbackResume', value);
      } catch (e) {
        Diagnostics.record('resume.save.error', {'error': e.toString()});
      }
    });
    return _resumeWrite;
  }

  Timer? _heartbeat;
  int _actionSerial = 0;
  int _queueRevision = 0;
  int _pendingActions = 0;
  void trace(String event, [Map<String, Object?> fields = const {}]) {
    Diagnostics.record(event, {
      'queueRevision': _queueRevision,
      'queueLength': queue.length,
      'index': index,
      'actualIndex': player.currentIndex,
      'track': queue.isEmpty ? null : current.id,
      'title': queue.isEmpty ? null : current.title,
      'positionMs': player.position.inMilliseconds,
      'processing': player.processingState.name,
      'playing': player.playing,
      'shuffle': player.shuffleModeEnabled,
      'repeat': player.loopMode.name,
      'pendingActions': _pendingActions,
      ...fields,
    });
  }

  final AudioPlayer player;
  final MusicStore store = MusicStore();
  final List<Track> catalog = [];
  final List<Track> queue = [];
  // Storage/source indices stay stable; UI follows the player's playback order.
  List<Track> get playbackQueue => player.effectiveIndices
      .where((i) => i >= 0 && i < queue.length)
      .map((i) => queue[i])
      .toList();
  bool get shuffled => player.shuffleModeEnabled;
  Map<String, ArtistInfo> artistInfo = {};
  ArtistDirectory? _artistDirectory;
  List<Track> _indexedTracks = [];
  Map<String, ArtistInfo> _indexedInfo = {};
  ArtistDirectory get artistDirectory {
    if (_artistDirectory == null ||
        !listEquals(catalog, _indexedTracks) ||
        !mapEquals(artistInfo, _indexedInfo)) {
      _indexedTracks = List.of(catalog);
      _indexedInfo = Map.of(artistInfo);
      _artistDirectory = ArtistDirectory(catalog, artistInfo);
    }
    return _artistDirectory!;
  }

  List<ArtistCollection> get artists => artistDirectory.artists;
  bool importing = false;
  String? importMessage;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Set<String> favorites = {};
  SharedPreferences? _prefs;
  bool ready = false, loading = true, _disposed = false;
  String? error;
  int index = 0;
  Track get current =>
      queue.isEmpty ? emptyTrack : queue[index.clamp(0, queue.length - 1)];
  bool get playing =>
      player.playing && player.processingState != ProcessingState.completed;
  FavoriteFragment? fragment;
  Duration get position =>
      player.position + Duration(milliseconds: fragment?.startMs ?? 0);
  Duration get duration => fragment != null
      ? Duration(milliseconds: current.durationMs)
      : player.duration ?? Duration(milliseconds: current.durationMs);
  LoopMode get repeat => player.loopMode;
  void _update() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _loadQueue(
    Iterable<Track> tracks, {
    int initialIndex = 0,
    Duration initialPosition = Duration.zero,
    FavoriteFragment? clip,
  }) async {
    fragment = clip;
    // Snapshot first: callers may pass the current queue itself.
    final selected = List<Track>.of(tracks);
    _queueRevision++;
    trace('queue.load.begin', {
      'requestedIndex': initialIndex,
      'tracks': selected
          .map((t) => {'id': t.id, 'title': t.title, 'artists': t.artistNames})
          .toList(),
    });
    queue
      ..clear()
      ..addAll(selected);
    await player.setAudioSources(
      queue
          .map(
            (track) => clip == null
                ? sourceFor(track)
                : ClippingAudioSource(
                    child: sourceFor(track) as UriAudioSource,
                    start: Duration(milliseconds: clip.startMs),
                    end: Duration(milliseconds: clip.endMs),
                    tag: mediaItemFor(track),
                  ),
          )
          .toList(),
      initialIndex: initialIndex,
      initialPosition: initialPosition,
    );
    trace('queue.load.end', {'requestedIndex': initialIndex});
    if (player.currentIndex != initialIndex) {
      trace('invariant.initial_index_mismatch', {'expected': initialIndex});
    }
  }

  Future<void> initialize() async {
    _heartbeat ??= Timer.periodic(const Duration(seconds: 5), (_) {
      if (player.playing) trace('player.heartbeat');
      unawaited(savePlayback());
    });

    trace('intent.initialize');
    loading = true;
    error = null;
    _update();
    var stage = 'preferences';
    try {
      _prefs = await SharedPreferences.getInstance();
      favorites = (_prefs!.getStringList('favorites') ?? []).toSet();
      if (!ready) {
        stage = 'tracks';
        final restored = await store.load();
        catalog.clear();
        catalog.addAll(restored);
        stage = 'artists';
        artistInfo = await store.loadArtists();
      }
      if (catalog.isNotEmpty) {
        stage = 'audioQueue';
        final resume = PlaybackResume.decode(
          _prefs!.getString('playbackResume'),
          catalog,
        );
        await player.setShuffleModeEnabled(false);
        await _loadQueue(
          resume?.tracks ?? catalog,
          initialIndex: resume?.index ?? 0,
        );
        if (resume != null) {
          await player.seek(resume.position, index: resume.index);
          await player.setLoopMode(
            LoopMode.values.firstWhere(
              (v) => v.name == resume.repeat,
              orElse: () => LoopMode.off,
            ),
          );
          if (resume.shuffle) {
            await player.shuffle();
            await player.setShuffleModeEnabled(true);
          }
          index = resume.index;
          trace('resume.restored');
        }
      }
      ready = true;
      trace('initialize.ready', {'tracks': catalog.length});
      debugPrint('Spun initialize: ready (${catalog.length} tracks)');
    } catch (exception, stack) {
      trace('initialize.error', {
        'stage': stage,
        'error': exception.toString(),
        'stack': stack.toString(),
      });
      debugPrint('Spun initialize failed at $stage: $exception\n$stack');
      error = 'Не удалось загрузить библиотеку. Нажмите «Повторить».';
    } finally {
      loading = false;
      _update();
    }
  }

  Future<void> _action(Future<void> Function() action) async {
    error = null;
    final actionId = ++_actionSerial;
    _pendingActions++;
    trace('action.begin', {'actionId': actionId});
    try {
      await action();
      trace('action.end', {'actionId': actionId});
    } catch (exception, stack) {
      trace('action.error', {
        'actionId': actionId,
        'error': exception.toString(),
        'stack': stack.toString(),
      });
      debugPrint('Spun playback failed: $exception\n$stack');
      error = 'Ошибка воспроизведения. Попробуйте ещё раз.';
    } finally {
      _pendingActions--;
      unawaited(savePlayback());
    }
    _update();
  }

  Future<void> select(Track track) async {
    trace('intent.select', {
      'selectedId': track.id,
      'selectedTitle': track.title,
    });
    if (!ready || catalog.isEmpty) return;
    if (fragment != null) return playCollection([track]);
    await _action(() async {
      if (!queue.any((t) => t.id == track.id)) {
        trace('queue.selection.stale', {'selectedId': track.id});
        return;
      }
      await player.seek(
        Duration.zero,
        index: queue.indexWhere((t) => t.id == track.id),
      );
      _startPlayback();
    });
  }

  Future<void> playFragment(Track track, FavoriteFragment clip) async {
    if (!ready || !clip.fits(track)) return;
    await _action(() async {
      trace('intent.fragment', {
        'fragmentId': clip.id,
        'startMs': clip.startMs,
        'endMs': clip.endMs,
      });
      await player.stop();
      await player.setShuffleModeEnabled(false);
      await player.setLoopMode(LoopMode.off);
      _loopBeforeWave = null;
      activeWavePreset = null;
      await _loadQueue([track], clip: clip);
      index = 0;
      _startPlayback();
    });
  }

  Future<void> playFullSong() =>
      playCollection([current], initialPosition: position);

  LoopMode? _loopBeforeWave;
  String? activeWavePreset;
  final Random _random;

  Future<void> playCollection(
    List<Track> tracks, {
    Track? startTrack,
    bool shuffle = false,
    bool repeatQueue = false,
    String? wavePreset,
    Duration initialPosition = Duration.zero,
  }) async {
    trace('intent.collection', {
      'selectedId': startTrack?.id,
      'selectedTitle': startTrack?.title,
      'shuffleRequested': shuffle,
    });
    if (!ready || tracks.isEmpty) return;
    final selectedTracks = List<Track>.of(tracks);
    await _action(() async {
      await player.stop();
      activeWavePreset = null;
      if (repeatQueue) {
        _loopBeforeWave ??= player.loopMode;
        await player.setLoopMode(LoopMode.all);
      } else if (_loopBeforeWave != null) {
        await player.setLoopMode(_loopBeforeWave!);
        _loopBeforeWave = null;
      }
      final start = startTrack == null
          ? (shuffle ? _random.nextInt(selectedTracks.length) : 0)
          : selectedTracks.indexWhere((t) => t.id == startTrack.id);
      final selectedIndex = start < 0 ? 0 : start;
      await player.setShuffleModeEnabled(false);
      final track = selectedTracks[selectedIndex];
      final upper = track.durationMs > 0
          ? (track.durationMs - 1000).clamp(0, track.durationMs)
          : 86400000;
      await _loadQueue(
        selectedTracks,
        initialIndex: selectedIndex,
        initialPosition: Duration(
          milliseconds: initialPosition.inMilliseconds.clamp(0, upper),
        ),
      );
      index = selectedIndex;
      if (shuffle) {
        await player.shuffle();
        await player.setShuffleModeEnabled(true);
        final first = player.effectiveIndices.first;
        await player.seek(Duration.zero, index: first);
      }
      activeWavePreset = repeatQueue ? wavePreset : null;
      _startPlayback();
    });
  }

  Future<void> toggle() async {
    trace('intent.toggle');
    if (!ready || catalog.isEmpty) return;
    if (playing) {
      await _action(player.pause);
    } else {
      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
      _startPlayback();
    }
  }

  Future<void> next() => _action(() async {
    trace('intent.next');
    _requestedDirection = 1;
    if (queue.isEmpty) return;
    if (player.hasNext) {
      await player.seekToNext();
    } else {
      await player.seek(Duration.zero, index: player.effectiveIndices.first);
    }
  });
  Future<void> previous({bool restartCurrent = true}) => _action(() async {
    trace('intent.previous');
    if (queue.isEmpty) return;
    if (restartCurrent && position.inSeconds > 3) {
      await player.seek(Duration.zero);
    } else if (player.hasPrevious) {
      _requestedDirection = -1;
      await player.seekToPrevious();
    } else {
      _requestedDirection = -1;
      await player.seek(Duration.zero, index: player.effectiveIndices.last);
    }
  });
  Future<void> seek(double seconds) => _action(() async {
    trace('intent.seek', {'targetMs': (seconds * 1000).round()});
    final clip = fragment;
    final target = (seconds * 1000).round();
    await player.seek(
      Duration(
        milliseconds: clip == null
            ? target
            : target.clamp(clip.startMs, clip.endMs) - clip.startMs,
      ),
    );
  });
  Future<void> toggleShuffle() => _action(() async {
    trace('intent.shuffle');
    final enable = !shuffled;
    if (enable) await player.shuffle();
    await player.setShuffleModeEnabled(enable);
  });
  Future<void> toggleRepeat() => _action(() async {
    trace('intent.repeat');
    await player.setLoopMode(switch (repeat) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    });
  });
  Future<void> favorite(Track track) async {
    trace('intent.favorite', {'selectedId': track.id});
    favorites.contains(track.id)
        ? favorites.remove(track.id)
        : favorites.add(track.id);
    _update();
    try {
      await _prefs?.setStringList('favorites', favorites.toList());
    } catch (_) {
      error = 'Не удалось сохранить избранное.';
      _update();
    }
  }

  AudioSource sourceFor(Track track) => track.imported
      ? AudioSource.uri(Uri.parse(track.localUri!), tag: mediaItemFor(track))
      : throw StateError("Track has no audio source");
  Future<void> importMusic() async {
    trace('intent.import');
    if (importing || !ready) return;
    importing = true;
    importMessage = null;
    _update();
    var added = 0;
    var failed = 0;
    var duplicates = 0;
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'flac', 'aiff', 'ogg'],
      );
      for (final picked in files) {
        Track? track;
        var enqueued = false;
        try {
          final size = await picked.length();
          if (size == null || size == 0 || size > 200 * 1024 * 1024) {
            failed++;
            continue;
          }
          track = await store.importFile(picked);
          final duplicate = catalog
              .where((t) => sameRecording(t, track!))
              .firstOrNull;
          if (duplicate != null) {
            if (duplicate.fileName != track.fileName) await store.delete(track);
            duplicates++;
            continue;
          }
          if (queue.isEmpty) {
            await player.setAudioSources([sourceFor(track)]);
            enqueued = true;
          }
          await store.save([...catalog, track]);
          catalog.add(track);
          if (enqueued) queue.add(track);
          added++;
        } catch (_) {
          if (enqueued) await player.removeAudioSourceAt(queue.length);
          if (track != null) await store.delete(track);
          failed++;
        }
      }
      if (files.isNotEmpty) {
        importMessage =
            'Добавлено: $added. Повторов пропущено: $duplicates${failed > 0 ? '. Не удалось добавить: $failed (лимит 200 МБ на файл).' : '.'}';
        if (kIsWeb && added > 0) {
          importMessage =
              '$importMessage В браузере файлы доступны до закрытия страницы.';
        }
      }
    } catch (_) {
      importMessage = 'Не удалось открыть файлы. Попробуйте ещё раз.';
    } finally {
      importing = false;
      _update();
    }
  }

  Future<void> removeImported(Track track) async {
    trace('intent.remove', {'selectedId': track.id});
    if (!track.imported || importing) return;
    importing = true;
    _update();
    await _action(() async {
      final i = catalog.indexOf(track);
      if (i < 0) return;
      // Save metadata first; source files outside the app are never removed.
      await store.save(catalog.where((t) => t.id != track.id));
      try {
        final qi = queue.indexWhere((t) => t.id == track.id);
        if (qi >= 0) await player.removeAudioSourceAt(qi);
      } catch (_) {
        await store.save(catalog);
        rethrow;
      }
      catalog.removeAt(i);
      queue.removeWhere((t) => t.id == track.id);
      if (queue.isEmpty) {
        await player.stop();
      }
      index = player.currentIndex ?? 0;
      favorites.remove(track.id);
      await _prefs?.setStringList('favorites', favorites.toList());
      await store.delete(track);
    });
    importing = false;
    _update();
  }

  @override
  void dispose() {
    _disposed = true;
    _heartbeat?.cancel();
    for (final s in _subscriptions) {
      s.cancel();
    }
    player.dispose();
    playbackProgress.dispose();
    super.dispose();
  }
}
