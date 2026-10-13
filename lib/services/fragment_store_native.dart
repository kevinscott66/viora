import 'fragment_repository.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/favorite_fragment.dart';

class FragmentStore implements FragmentRepository {
  FragmentStore({this.directory});
  final Directory? directory;
  Future<Directory> get root async =>
      (directory ??
              Directory(
                '${(await getApplicationDocumentsDirectory()).path}/Fragments',
              ))
          .create(recursive: true);
  @override
  Future<List<FavoriteFragment>> load() async {
    final result = <FavoriteFragment>[];
    await for (final file in (await root).list()) {
      if (file is File && file.path.endsWith('.json')) {
        result.add(
          FavoriteFragment.fromJson(jsonDecode(await file.readAsString())),
        );
      }
    }
    result.sort((a, b) => b.id.compareTo(a.id));
    return result;
  }

  @override
  Future<void> save(FavoriteFragment entry) async {
    final checked = FavoriteFragment.fromJson(entry.toJson());
    final path = '${(await root).path}/${checked.id}.json';
    final temporary = File('$path.tmp');
    await temporary.writeAsString(jsonEncode(checked.toJson()), flush: true);
    await temporary.rename(path);
  }

  @override
  Future<void> delete(FavoriteFragment entry) async {
    FavoriteFragment.fromJson(entry.toJson());
    final file = File('${(await root).path}/${entry.id}.json');
    if (await file.exists()) await file.delete();
  }
}
