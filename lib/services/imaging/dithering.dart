import 'dart:typed_data';

import 'package:peripage_app/services/imaging/mono_bitmap.dart';

enum DitherMode { off, floyd, atkinson }

abstract final class Dithering {
  /// Threshold used when dithering is off (the official app uses 190 on pre-processed bitmaps).
  static const threshold = 128;

  static MonoBitmap apply(GrayImage image, DitherMode mode) {
    return switch (mode) {
      DitherMode.off => _threshold(image),
      DitherMode.floyd => _diffuse(image, _floyd),
      DitherMode.atkinson => _diffuse(image, _atkinson),
    };
  }

  static MonoBitmap _threshold(GrayImage image) {
    final out = Uint8List(image.width * image.height);
    for (var i = 0; i < out.length; i++) {
      out[i] = image.luma[i] < threshold ? 1 : 0;
    }
    return MonoBitmap(image.width, image.height, out);
  }

  // (dx, dy, weight) with a common divisor.
  static const _floyd = (16, [(1, 0, 7), (-1, 1, 3), (0, 1, 5), (1, 1, 1)]);
  static const _atkinson = (8, [(1, 0, 1), (2, 0, 1), (-1, 1, 1), (0, 1, 1), (1, 1, 1), (0, 2, 1)]);

  static MonoBitmap _diffuse(GrayImage image, (int, List<(int, int, int)>) kernel) {
    final (divisor, taps) = kernel;
    final w = image.width;
    final h = image.height;
    final buffer = Int16List(w * h)..setAll(0, image.luma);
    final out = Uint8List(w * h);

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        final old = buffer[i];
        final black = old < 128;
        out[i] = black ? 1 : 0;
        final error = old - (black ? 0 : 255);
        if (error == 0) continue;

        for (final (dx, dy, weight) in taps) {
          final nx = x + dx;
          final ny = y + dy;
          if (nx < 0 || nx >= w || ny >= h) continue;
          final j = ny * w + nx;
          buffer[j] = (buffer[j] + error * weight ~/ divisor).clamp(-255, 510);
        }
      }
    }
    return MonoBitmap(w, h, out);
  }
}
