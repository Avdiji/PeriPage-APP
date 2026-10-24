import 'dart:typed_data';

/// 8-bit greyscale image (0 = black, 255 = white), row-major.
final class GrayImage {
  final int width;
  final int height;
  final Uint8List luma;

  GrayImage(this.width, this.height, this.luma) : assert(luma.length == width * height);
}

/// 1-bit image ready for the print head, one byte per pixel (1 = black), row-major.
final class MonoBitmap {
  final int width;
  final int height;
  final Uint8List pixels;

  MonoBitmap(this.width, this.height, this.pixels) : assert(pixels.length == width * height);

  bool isBlack(int x, int y) => pixels[y * width + x] == 1;
}
