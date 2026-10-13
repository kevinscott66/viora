import 'diary_repository.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/diary_entry.dart';

class DiaryStore implements DiaryRepository {
  DiaryStore({this.directory});
  final Directory? directory;
  Future<Directory> get root async =>
      (directory ??
              Directory(
                '${(await getApplicationDocumentsDirectory()).path}/Diary',
              ))
          .create(recursive: true);
  @override
  Future<List<DiaryEntry>> load() async {
    final result = <DiaryEntry>[];
    await for (final file in (await root).list()) {
      if (file is File && file.path.endsWith('.json')) {
        result.add(DiaryEntry.fromJson(jsonDecode(await file.readAsString())));
      }
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  @override
  Future<void> save(DiaryEntry entry) async {
    final checked = DiaryEntry.fromJson(entry.toJson());
    final path = '${(await root).path}/${checked.id}.json';
    final temporary = File('$path.tmp');
    await temporary.writeAsString(jsonEncode(checked.toJson()), flush: true);
    await temporary.rename(path);
  }

  @override
  Future<void> delete(DiaryEntry entry) async {
    DiaryEntry.fromJson(entry.toJson());
    final file = File('${(await root).path}/${entry.id}.json');
    if (await file.exists()) await file.delete();
  }
}
