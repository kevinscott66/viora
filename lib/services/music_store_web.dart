import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/track.dart';
import '../models/artist.dart';
import 'library_codec.dart';

// A local preview catalog is opt-in and never bundled into the mobile build.
class MusicStore {
  static const preview = bool.fromEnvironment('SPUN_PREVIEW');
  Uri resolve(String path) => Uri.base.resolve('preview/$path');
  Future<List<dynamic>> read(String name) async {
    if (!preview) return [];
    final response = await http.get(resolve(name));
    if (response.statusCode != 200) return [];
    return jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
  }

  LibraryCodec get codec => LibraryCodec(
    audioUri: (name) => resolve(name).toString(),
    imagePath: (name) => resolve(name).toString(),
  );
  Future<List<Track>> load() async => [
    for (final row in await read('library.json'))
      ?codec.decodeTrack(row as Map<String, dynamic>),
  ];
  Future<Map<String, ArtistInfo>> loadArtists() async => {
    for (final row in await read('artists.json'))
      row['name'] as String: codec.decodeArtist(row as Map<String, dynamic>),
  };
  Future<Track> importFile(PlatformFile picked) async => Track(
    'local_${DateTime.now().microsecondsSinceEpoch}',
    titleFromFile(picked.name),
    'Неизвестный исполнитель',
    const Color(0xff53528e),
    localUri: picked.uri.toString(),
    fileName: picked.name,
  );
  Future<void> save(Iterable<Track> tracks) async {}
  Future<void> delete(Track track) async {}
}
