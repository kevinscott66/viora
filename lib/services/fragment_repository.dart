import '../models/favorite_fragment.dart';

abstract interface class FragmentRepository {
  Future<List<FavoriteFragment>> load();
  Future<void> save(FavoriteFragment entry);
  Future<void> delete(FavoriteFragment entry);
}
