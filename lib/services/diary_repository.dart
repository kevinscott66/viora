import '../models/diary_entry.dart';

abstract interface class DiaryRepository {
  Future<List<DiaryEntry>> load();
  Future<void> save(DiaryEntry entry);
  Future<void> delete(DiaryEntry entry);
}
