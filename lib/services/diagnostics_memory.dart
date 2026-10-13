final List<String> lines = [];
Future<void> initialize() async {}
Future<void> append(String line) async {
  lines.add(line);
  if (lines.length > 1000) lines.removeAt(0);
}
