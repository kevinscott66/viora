import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/track.dart';
import '../models/artist.dart';
import 'library_codec.dart';

class MusicStore {
  MusicStore({this.directory});
  final Directory? directory;
  Future<Directory> get root async =>
      (directory ??
              Directory(
                '${(await getApplicationDocumentsDirectory()).path}/Music',
              ))
          .create(recursive: true);
  LibraryCodec codec(Directory dir) => LibraryCodec(
    audioUri: (name) => File('${dir.path}/$name').uri.toString(),
    imagePath: (name) => '${dir.path}/$name',
  );
  Future<List<Track>> load() async {
    final dir = await root;
    final manifest = File('${dir.path}/library.json');
    if (!await manifest.exists()) return [];
    final rows = jsonDecode(await manifest.readAsString()) as List<dynamic>;
    final result = <Track>[];
    final decoder = codec(dir);
    for (final row in rows) {
      final track = decoder.decodeTrack(row as Map<String, dynamic>);
      if (track != null &&
          await File.fromUri(Uri.parse(track.localUri!)).exists()) {
        result.add(track);
      }
    }
    return result;
  }

  Future<Map<String, ArtistInfo>> loadArtists() async {
    final dir = await root;
    final file = File('${dir.path}/artists.json');
    if (!await file.exists()) return {};
    final rows = jsonDecode(await file.readAsString()) as List<dynamic>;
    final decoder = codec(dir);
    return {
      for (final row in rows)
        row['name'] as String: decoder.decodeArtist(
          row as Map<String, dynamic>,
        ),
    };
  }

  Future<Track> importFile(PlatformFile picked) async {
    final dir = await root;
    final ext = picked.name.split('.').last.toLowerCase();
    if (!RegExp(r'^[a-z0-9]{1,8}$').hasMatch(ext)) {
      throw const FormatException('Invalid extension');
    }
    final temporary = File(
      '${dir.path}/import_${DateTime.now().microsecondsSinceEpoch}.$ext',
    );
    final sink = temporary.openWrite();
    try {
      await sink.addStream(picked.readAsByteStream());
      await sink.flush();
    } catch (_) {
      await sink.close();
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
    await sink.close();
    final hash = await sha256.bind(temporary.openRead()).first;
    final id = 'local_$hash';
    final name = '$id.$ext';
    final file = File('${dir.path}/$name');
    if (await file.exists()) {
      await temporary.delete();
    } else {
      await temporary.rename(file.path);
    }
    final path = file.path;
    final metadata = await Isolate.run(() {
      try {
        final m = readMetadata(File(path), getImage: true);
        final picture =
            m.pictures
                .where((p) => p.pictureType == PictureType.coverFront)
                .firstOrNull ??
            m.pictures.firstOrNull;
        return <String, dynamic>{
          'title': m.title,
          'artist': m.artist,
          'album': m.album,
          'durationMs': m.duration?.inMilliseconds,
          'picture': picture?.bytes,
        };
      } catch (_) {
        return <String, dynamic>{};
      }
    });
    String? cover;
    final bytes = metadata['picture'] as List<int>?;
    if (bytes != null && bytes.isNotEmpty && bytes.length < 15000000) {
      cover = '$id.cover';
      await File('${dir.path}/$cover').writeAsBytes(bytes);
    }
    final title = (metadata['title'] as String?)?.trim();
    final artist = (metadata['artist'] as String?)?.trim();
    return Track(
      id,
      title?.isNotEmpty == true ? title! : titleFromFile(picked.name),
      artist?.isNotEmpty == true ? artist! : 'Неизвестный исполнитель',
      HSLColor.fromAHSL(
        1,
        int.parse(hash.toString().substring(0, 4), radix: 16) % 360,
        .4,
        .32,
      ).toColor(),
      localUri: file.uri.toString(),
      fileName: name,
      album: metadata['album'] as String? ?? '',
      durationMs: metadata['durationMs'] as int? ?? 0,
      artworkFile: cover,
      artworkPath: cover == null ? null : '${dir.path}/$cover',
    );
  }

  Future<void> save(Iterable<Track> tracks) async {
    final dir = await root;
    final temp = File('${dir.path}/library.json.tmp');
    await temp.writeAsString(
      jsonEncode(
        tracks.where((t) => t.imported).map(LibraryCodec.encodeTrack).toList(),
      ),
      flush: true,
    );
    await temp.rename('${dir.path}/library.json');
  }

  Future<void> delete(Track track) async {
    final dir = await root;
    for (final value in [track.fileName, track.artworkFile]) {
      final name = LibraryCodec.safeName(value);
      if (name == null) continue;
      final file = File('${dir.path}/$name');
      if (await file.exists()) await file.delete();
    }
  }
}
