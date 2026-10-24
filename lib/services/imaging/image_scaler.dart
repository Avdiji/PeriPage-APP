import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:peripage_app/services/imaging/mono_bitmap.dart';

/// Brings a decoded image into the printer's geometry and converts it to greyscale.
abstract final class ImageScaler {
  /// [fitWidth] scales to exactly [width] dots; otherwise the image keeps its size (downscaled only if
  /// wider than the head) and is centred. [quarterTurns] rotates clockwise in 90° steps.
  ///
  /// Scales before rotating, so the rotation only ever touches a print-sized image.
  static GrayImage toPrintGray(
    img.Image source, {
    required int width,
    required bool fitWidth,
    required int quarterTurns,
  }) {
    final turns = quarterTurns % 4;
    final printedWidth = turns.isOdd ? source.height : source.width;
    final targetWidth = fitWidth || printedWidth > width ? width : printedWidth;

    var image = source;
    if (targetWidth != printedWidth) {
      final scale = targetWidth / printedWidth;
      image = img.copyResize(
        source,
        width: (source.width * scale).round().clamp(1, 1 << 16),
        height: (source.height * scale).round().clamp(1, 1 << 16),
        interpolation: scale < 1 ? img.Interpolation.average : img.Interpolation.linear,
      );
    }
    if (turns != 0) image = img.copyRotate(image, angle: 90 * turns);

    // Raw RGBA bytes with integer maths: an A4 page has ~4 million pixels, per-pixel objects are too slow.
    final rgba = image.convert(format: img.Format.uint8, numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
    final drawWidth = image.width < width ? image.width : width;
    final offsetX = (width - drawWidth) ~/ 2;
    final height = image.height;
    final out = Uint8List(width * height)..fillRange(0, width * height, 255);

    for (var y = 0; y < height; y++) {
      var src = y * image.width * 4;
      var dst = y * width + offsetX;
      for (var x = 0; x < drawWidth; x++, src += 4, dst++) {
        // Rec. 601 luma ×1000, then composite over white paper using alpha.
        final luma = (299 * rgba[src] + 587 * rgba[src + 1] + 114 * rgba[src + 2]) ~/ 1000;
        final alpha = rgba[src + 3];
        out[dst] = (luma * alpha + 255 * (255 - alpha)) ~/ 255;
      }
    }
    return GrayImage(width, height, out);
  }

  /// Small PNG thumbnail of a 1-bit bitmap for the history list.
  static Uint8List thumbnailPng(MonoBitmap bitmap, {int width = 96}) {
    final scale = width / bitmap.width;
    final height = (bitmap.height * scale).ceil().clamp(1, 4096);
    final thumb = img.Image(width: width, height: height, numChannels: 1);
    for (var y = 0; y < height; y++) {
      final sy = (y / scale).floor().clamp(0, bitmap.height - 1);
      for (var x = 0; x < width; x++) {
        final sx = (x / scale).floor().clamp(0, bitmap.width - 1);
        final v = bitmap.isBlack(sx, sy) ? 0 : 255;
        thumb.setPixelRgb(x, y, v, v, v);
      }
    }
    return img.encodePng(thumb);
  }
}
