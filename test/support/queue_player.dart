import 'dart:async';
import 'package:just_audio/just_audio.dart';

// Deliberately non-sequential order: catches confusing source indices with
// visible row positions, including wraparound at either end.
class QueuePlayer implements AudioPlayer {
  final indices = StreamController<int?>.broadcast(sync: true);
  bool emitOldIndexOnShuffle = false;
  final changes = StreamController<SequenceState>.broadcast();
  @override
  bool get playing => false;
  @override
  ProcessingState get processingState => ProcessingState.ready;
  @override
  Duration? get duration => const Duration(minutes: 3);
  @override
  LoopMode get loopMode => LoopMode.off;
  bool enabled = false;
  int cursor = 0;
  @override
  int? get currentIndex => cursor;
  @override
  List<int> get effectiveIndices => enabled ? [2, 0, 1] : [0, 1, 2];
  @override
  bool get shuffleModeEnabled => enabled;
  @override
  Stream<SequenceState> get sequenceStateStream => changes.stream;
  @override
  Stream<PlayerState> get playerStateStream => const Stream.empty();
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<int?> get currentIndexStream => indices.stream;
  @override
  Stream<PlayerException> get errorStream => const Stream.empty();
  @override
  Duration get position => Duration.zero;
  @override
  bool get hasNext => effectiveIndices.indexOf(cursor) < 2;
  @override
  bool get hasPrevious => effectiveIndices.indexOf(cursor) > 0;
  @override
  Future<void> seek(Duration? position, {int? index}) async {
    if (index != null) cursor = index;
  }

  @override
  Future<void> seekToNext() async =>
      cursor = effectiveIndices[effectiveIndices.indexOf(cursor) + 1];
  @override
  Future<void> seekToPrevious() async =>
      cursor = effectiveIndices[effectiveIndices.indexOf(cursor) - 1];
  @override
  Future<void> shuffle() async {}
  @override
  Future<void> setShuffleModeEnabled(bool enabled) async {
    this.enabled = enabled;
    if (emitOldIndexOnShuffle) indices.add(cursor);
  }

  @override
  Future<void> play() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<Duration?> setAudioSources(
    List<AudioSource> sources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    ShuffleOrder? shuffleOrder,
  }) async {
    cursor = initialIndex ?? 0;
    return null;
  }

  @override
  Future<void> dispose() async {
    await changes.close();
    await indices.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
