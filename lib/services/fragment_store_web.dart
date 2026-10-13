import 'fragment_repository.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/favorite_fragment.dart';

class FragmentStore implements FragmentRepository {
  @override
  Future<List<FavoriteFragment>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs
        .getKeys()
        .where((k) => k.startsWith('fragment.'))
        .map((k) => FavoriteFragment.fromJson(jsonDecode(prefs.getString(k)!)))
        .toList();
    entries.sort((a, b) => b.id.compareTo(a.id));
    return entries;
  }

  @override
  Future<void> save(FavoriteFragment entry) async {
    FavoriteFragment.fromJson(entry.toJson());
    if (!await (await SharedPreferences.getInstance()).setString(
      'fragment.${entry.id}',
      jsonEncode(entry.toJson()),
    )) {
      throw StateError('Fragments write failed');
    }
  }

  @override
  Future<void> delete(FavoriteFragment entry) async {
    if (!await (await SharedPreferences.getInstance()).remove(
      'fragment.${entry.id}',
    )) {
      throw StateError('Fragments delete failed');
    }
  }
}
