/// Artist identity preserves punctuation and non-Latin names. Track title
/// matching intentionally uses different, more permissive normalization.
String artistKey(String name) => name
    .trim()
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'\s+'), ' ');

List<String> artistCredits(String artist, List<String> performers) {
  // Explicit credits are authoritative: a band's name may contain commas or &.
  final candidates = performers.any((name) => name.trim().isNotEmpty)
      ? performers
      : artist.split(
          RegExp(
            r'\s*(?:,|;)\s*|\s+(?:&|x|feat\.?|ft\.?|featuring)\s+',
            caseSensitive: false,
          ),
        );
  final names = <String, String>{};
  for (final value in candidates) {
    final name = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    final key = artistKey(name);
    if (key.isEmpty || key == artistKey('Неизвестный исполнитель')) continue;
    names.putIfAbsent(key, () => name);
  }
  return List.unmodifiable(names.values);
}
