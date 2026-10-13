import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// CPU work runs in compute(), away from playback and UI on mobile.
Uint8List encodeMomentAnimation(List<Uint8List> frames) {
  if (frames.isEmpty || frames.length > 24) {
    throw ArgumentError('Expected 1–24 postcard frames');
  }
  final encoder = img.GifEncoder(
    repeat: 0,
    quantizerType: img.QuantizerType.octree,
    dither: img.DitherKernel.none,
  );
  for (final bytes in frames) {
    final frame = img.decodePng(bytes);
    if (frame == null) throw StateError('Invalid postcard frame');
    // iOS can capture wide-gamut surfaces as 16-bit PNGs. The octree
    // quantizer indexes 8-bit RGB channels; normalize before quantization
    // instead of letting the larger values wrap into a corrupt palette.
    final normalized = frame.convert(format: img.Format.uint8, numChannels: 4);
    encoder.addFrame(normalized, duration: 12); // 2.88 second loop.
  }
  return encoder.finish()!;
}
