import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/track.dart';

/// Must run before the app creates its single AudioPlayer.
Future<void> initializeBackgroundAudio() async {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.iOS &&
          defaultTargetPlatform != TargetPlatform.android)) {
    return;
  }
  await JustAudioBackground.init(
    androidNotificationChannelId: 'tech.dobropalm.spunMusic.playback',
    androidNotificationChannelName: 'Воспроизведение музыки',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'drawable/ic_stat_music',
  );
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
}

MediaItem mediaItemFor(Track track) {
  final artwork = track.artworkPath;
  return MediaItem(
    id: track.id,
    title: track.title,
    artist: track.artistNames.isEmpty
        ? track.artist
        : track.artistNames.join(', '),
    album: track.album.isEmpty ? null : track.album,
    duration: track.durationMs > 0
        ? Duration(milliseconds: track.durationMs)
        : null,
    artUri: artwork == null
        ? null
        : (Uri.parse(artwork).hasScheme
              ? Uri.parse(artwork)
              : Uri.file(artwork)),
  );
}
