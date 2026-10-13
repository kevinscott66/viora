import 'diary_repository.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diary_entry.dart';

class DiaryStore implements DiaryRepository {
  @override
  Future<List<DiaryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs
        .getKeys()
        .where((k) => k.startsWith('diary.'))
        .map((k) => DiaryEntry.fromJson(jsonDecode(prefs.getString(k)!)))
        .toList();
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  @override
  Future<void> save(DiaryEntry entry) async {
    DiaryEntry.fromJson(entry.toJson());
    if (!await (await SharedPreferences.getInstance()).setString(
      'diary.${entry.id}',
      jsonEncode(entry.toJson()),
    )) {
      throw StateError('Diary write failed');
    }
  }

  @override
  Future<void> delete(DiaryEntry entry) async {
    if (!await (await SharedPreferences.getInstance()).remove(
      'diary.${entry.id}',
    )) {
      throw StateError('Diary delete failed');
    }
  }
}
