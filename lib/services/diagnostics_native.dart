import 'dart:io';
import 'package:path_provider/path_provider.dart';

Directory? _directory;
int _bytes = 0;
const limit = 1024 * 1024;
Future<void> initialize() async {
  final docs = await getApplicationDocumentsDirectory();
  _directory = await Directory(
    '${docs.path}/Diagnostics',
  ).create(recursive: true);
  final file = File('${_directory!.path}/events.jsonl');
  _bytes = await file.exists() ? await file.length() : 0;
}

Future<void> append(String line) async {
  if (_directory == null) return;
  final root = _directory!.path;
  final file = File('$root/events.jsonl');
  if (_bytes >= limit) {
    final oldest = File('$root/events.3.jsonl');
    if (await oldest.exists()) await oldest.delete();
    for (var i = 2; i >= 1; i--) {
      final old = File('$root/events.$i.jsonl');
      if (await old.exists()) await old.rename('$root/events.${i + 1}.jsonl');
    }
    if (await file.exists()) await file.rename('$root/events.1.jsonl');
    _bytes = 0;
  }
  await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
  _bytes = await file.length();
}
