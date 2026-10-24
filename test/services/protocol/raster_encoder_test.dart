import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:peripage_app/services/imaging/mono_bitmap.dart';
import 'package:peripage_app/services/protocol/raster_encoder.dart';

void main() {
  test('packs pixels MSB first and pads rows to whole bytes', () {
    // 10 px wide → 2 bytes per row.
    final pixels = Uint8List(20);
    pixels[0] = 1; // row 0, x 0
    pixels[9] = 1; // row 0, x 9
    pixels[10 + 7] = 1; // row 1, x 7
    final packed = RasterEncoder.packRows(MonoBitmap(10, 2, pixels));
    expect(packed, [0x80, 0x40, 0x01, 0x00]);
  });

  test('GS v 0 header carries bytes-per-row and height little-endian', () {
    final bitmap = MonoBitmap(384, 300, Uint8List(384 * 300));
    final frame = RasterEncoder.gsv0(bitmap);
    expect(frame.sublist(0, 8), [0x1D, 0x76, 0x30, 0x00, 48, 0, 300 & 0xFF, 300 >> 8]);
    expect(frame.length, 8 + 48 * 300);
  });
}
