import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:peripage_app/services/imaging/dithering.dart';
import 'package:peripage_app/services/imaging/mono_bitmap.dart';

GrayImage _flat(int value, {int size = 32}) => GrayImage(size, size, Uint8List(size * size)..fillRange(0, size * size, value));

double _coverage(MonoBitmap b) => b.pixels.where((p) => p == 1).length / b.pixels.length;

void main() {
  test('threshold maps black and white exactly', () {
    expect(_coverage(Dithering.apply(_flat(0), DitherMode.off)), 1);
    expect(_coverage(Dithering.apply(_flat(255), DitherMode.off)), 0);
  });

  test('Floyd–Steinberg reproduces mid grey as ~50 % ink', () {
    expect(_coverage(Dithering.apply(_flat(128), DitherMode.floyd)), closeTo(.5, .05));
  });

  test('Atkinson keeps highlights lighter than Floyd–Steinberg', () {
    final atkinson = _coverage(Dithering.apply(_flat(200), DitherMode.atkinson));
    final floyd = _coverage(Dithering.apply(_flat(200), DitherMode.floyd));
    expect(atkinson, lessThanOrEqualTo(floyd));
  });
}
