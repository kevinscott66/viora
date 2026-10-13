import 'package:flutter_test/flutter_test.dart';
import 'package:spun_music/services/library_codec.dart';

void main() {
  final codec = LibraryCodec(audioUri: (s) => s, imagePath: (s) => s);
  test('portrait positioning is optional and isolated to each artist', () {
    final lida = codec.decodeArtist({'name': 'Example artist 414', 'imageAlignmentY': 0.35});
    final legacy = codec.decodeArtist({'name': 'Other artist'});
    expect(lida.imageAlignmentY, 0.35);
    expect(legacy.imageAlignmentY, -1);
    expect(
      codec.decodeArtist({
        'name': 'Other',
        'imageAlignmentY': 5,
      }).imageAlignmentY,
      1,
    );
  });
}
