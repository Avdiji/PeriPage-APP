import 'dart:typed_data';

import 'package:peripage_app/services/imaging/mono_bitmap.dart';

abstract final class RasterEncoder {
  /// Packs pixels into rows of `ceil(width / 8)` bytes, MSB = leftmost pixel, 1 = black.
  static Uint8List packRows(MonoBitmap bitmap) {
    final bytesPerRow = (bitmap.width + 7) >> 3;
    final out = Uint8List(bytesPerRow * bitmap.height);

    for (var y = 0; y < bitmap.height; y++) {
      final rowOffset = y * bytesPerRow;
      final pixelOffset = y * bitmap.width;
      for (var x = 0; x < bitmap.width; x++) {
        if (bitmap.pixels[pixelOffset + x] == 1) {
          out[rowOffset + (x >> 3)] |= 0x80 >> (x & 7);
        }
      }
    }
    return out;
  }

  /// ESC/POS `GS v 0` raster frame: `1D 76 30 m xL xH yL yH` followed by the packed rows.
  static Uint8List gsv0(MonoBitmap bitmap) {
    final bytesPerRow = (bitmap.width + 7) >> 3;
    final height = bitmap.height;
    final header = [0x1D, 0x76, 0x30, 0x00, bytesPerRow & 0xFF, bytesPerRow >> 8, height & 0xFF, height >> 8];
    return (BytesBuilder(copy: false)
          ..add(header)
          ..add(packRows(bitmap)))
        .toBytes();
  }
}
