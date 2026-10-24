// Draws the app icon: a white thermal printer feeding out a printed receipt, on the app's coral accent.
//
//   fvm dart run tool/generate_icon.dart        -> assets/icon/icon.png, assets/icon/icon_foreground.png
//   fvm dart run flutter_launcher_icons          -> Windows .ico + Android launcher icons
//
// Shapes are drawn at 4× and downsampled for smooth edges (package:image has no antialiased rects).
import 'dart:io';

import 'package:image/image.dart' as img;

const _size = 1024;
const _ss = 4;

final _coralTop = img.ColorRgba8(0xF2, 0x6B, 0x50, 0xFF);
final _coralBottom = img.ColorRgba8(0xD9, 0x45, 0x2D, 0xFF);
final _white = img.ColorRgba8(0xFF, 0xFF, 0xFF, 0xFF);
final _paperEdge = img.ColorRgba8(0xE4, 0xDF, 0xD6, 0xFF);
final _ink = img.ColorRgba8(0x2B, 0x2F, 0x36, 0xFF);
final _slot = img.ColorRgba8(0x1B, 0x1F, 0x24, 0xFF);
final _shadow = img.ColorRgba8(0x00, 0x00, 0x00, 0x30);

void main() {
  Directory('assets/icon').createSync(recursive: true);

  // Full icon (Windows, legacy Android): rounded coral tile with the printer.
  final full = _canvas();
  _tile(full);
  _printer(full, scale: 1);
  File('assets/icon/icon.png').writeAsBytesSync(img.encodePng(_downsample(full)));

  // Android adaptive foreground: printer only, inside the 66 % safe zone; the background is a flat colour.
  final foreground = _canvas();
  _printer(foreground, scale: .62);
  File('assets/icon/icon_foreground.png').writeAsBytesSync(img.encodePng(_downsample(foreground)));

  stdout.writeln('Wrote assets/icon/icon.png and assets/icon/icon_foreground.png');
}

img.Image _canvas() => img.Image(width: _size * _ss, height: _size * _ss, numChannels: 4);

img.Image _downsample(img.Image big) =>
    img.copyResize(big, width: _size, height: _size, interpolation: img.Interpolation.average);

/// Rounded square with a soft vertical gradient.
void _tile(img.Image canvas) {
  const side = _size * _ss;
  final mask = img.Image(width: side, height: side);
  img.fillRect(mask, x1: 0, y1: 0, x2: side - 1, y2: side - 1, color: _white, radius: 230 * _ss);

  const band = 8;
  for (var y = 0; y < side; y += band) {
    final t = y / side;
    final color = img.ColorRgba8(
      (_coralTop.r + (_coralBottom.r - _coralTop.r) * t).round(),
      (_coralTop.g + (_coralBottom.g - _coralTop.g) * t).round(),
      (_coralTop.b + (_coralBottom.b - _coralTop.b) * t).round(),
      0xFF,
    );
    img.fillRect(canvas, x1: 0, y1: y, x2: side - 1, y2: y + band - 1, color: color, mask: mask);
  }
}

/// Printer and receipt in a 1024 design space, scaled around the artwork's centre into the canvas centre.
void _printer(img.Image canvas, {required double scale}) {
  const centerX = 512, centerY = 475;
  int x(num v) => (((v - centerX) * scale + 512) * _ss).round();
  int y(num v) => (((v - centerY) * scale + 512) * _ss).round();
  int r(num v) => (v * scale * _ss).round();
  void rect(num x1, num y1, num x2, num y2, img.Color color, [num radius = 0]) =>
      img.fillRect(canvas, x1: x(x1), y1: y(y1), x2: x(x2), y2: y(y2), color: color, radius: r(radius));

  // Body with a soft drop shadow.
  rect(244, 470, 780, 816, _shadow, 96);
  rect(232, 440, 792, 790, _white, 96);

  // Receipt coming out of the slot, with a hairline edge so it reads against the white body.
  rect(374, 154, 650, 492, _paperEdge, 22);
  rect(380, 160, 644, 492, _white, 18);
  for (final (top, width) in [(214, 196), (270, 148), (326, 178), (382, 104)]) {
    rect(414, top, 414 + width, top + 24, _ink, 12);
  }

  // Paper slot drawn over the receipt's lower end, so it looks like it is being fed out.
  rect(326, 468, 698, 506, _slot, 19);

  // Status light.
  img.fillCircle(canvas, x: x(706), y: y(718), radius: r(24), color: _coralBottom, antialias: true);
}
