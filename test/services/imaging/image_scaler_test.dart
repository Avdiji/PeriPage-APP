import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:peripage_app/services/imaging/image_scaler.dart';

void main() {
  img.Image landscape() => img.Image(width: 200, height: 100)..clear(img.ColorRgb8(0, 0, 0));

  test('fit width without rotation keeps the aspect ratio', () {
    final gray = ImageScaler.toPrintGray(landscape(), width: 40, fitWidth: true, quarterTurns: 0);
    expect((gray.width, gray.height), (40, 20));
  });

  test('a quarter turn makes the former height the printed width', () {
    final gray = ImageScaler.toPrintGray(landscape(), width: 40, fitWidth: true, quarterTurns: 1);
    expect((gray.width, gray.height), (40, 80));
    expect(gray.luma.every((v) => v == 0), isTrue); // black source stays black, no white seams
  });

  test('original size is centred on the head', () {
    final gray = ImageScaler.toPrintGray(img.Image(width: 10, height: 4), width: 40, fitWidth: false, quarterTurns: 0);
    expect((gray.width, gray.height), (40, 4));
    expect(gray.luma[0], 255); // white margin left of the centred image
  });
}
