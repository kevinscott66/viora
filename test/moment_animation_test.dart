import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:spun_music/services/moment_animation.dart';

void main() {
  test('16-bit capture retains the same colours as an 8-bit capture', () {
    final source = img.Image(width: 48, height: 32, numChannels: 4);
    for (final p in source) {
      p.setRgba(p.x * 5, p.y * 7, (p.x + p.y) * 3, 255);
    }
    final highDepth = source.convert(format: img.Format.uint16);
    final decodedHighDepth = img.decodePng(img.encodePng(highDepth))!;
    expect(decodedHighDepth.format, img.Format.uint16);
    final standard = encodeMomentAnimation([img.encodePng(source)]);
    final wide = encodeMomentAnimation([img.encodePng(highDepth)]);
    expect(wide, orderedEquals(standard));
  });

  test('export is a looping GIF preserving frame dimensions and timing', () {
    final a = img.Image(width: 32, height: 48);
    img.fill(a, color: img.ColorRgb8(180, 30, 60));
    final b = img.Image(width: 32, height: 48);
    img.fill(b, color: img.ColorRgb8(30, 60, 180));
    final result = img.decodeGif(
      encodeMomentAnimation([img.encodePng(a), img.encodePng(b)]),
    )!;
    expect(result.numFrames, 2);
    expect(result.width, 32);
    expect(result.height, 48);
    expect(result.loopCount, 0);
    expect(result.frames.first.frameDuration, 120);
    expect(result.frames.first.getPixel(0, 0).r, greaterThan(100));
    expect(result.frames.last.getPixel(0, 0).b, greaterThan(100));
    expect(() => encodeMomentAnimation([]), throwsArgumentError);
  });
}
