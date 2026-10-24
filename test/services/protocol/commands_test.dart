import 'package:flutter_test/flutter_test.dart';
import 'package:peripage_app/services/protocol/commands.dart';

void main() {
  test('queries match the official app', () {
    expect(Commands.queryModel(), [0x10, 0xFF, 0x20, 0xF0]);
    expect(Commands.queryFirmware(), [0x10, 0xFF, 0x20, 0xF1]);
    expect(Commands.querySerial(), [0x10, 0xFF, 0x20, 0xF2]);
    expect(Commands.queryBattery(), [0x10, 0xFF, 0x50, 0xF1]);
    expect(Commands.queryStatus(), [0x10, 0xFF, 0x40]);
  });

  test('settings encode their argument', () {
    expect(Commands.setDensity(2), [0x10, 0xFF, 0x10, 0x00, 0x02]);
    expect(Commands.setPaperType(2), [0x10, 0xFF, 0x10, 0x03, 0x02]);
    expect(Commands.setAutoOff(300), [0x10, 0xFF, 0x12, 0x01, 0x2C]);
  });

  test('job framing', () {
    expect(Commands.startJob(), [0x10, 0xFF, 0xFE, 0x01]);
    expect(Commands.endJob(), [0x10, 0xFF, 0xFE, 0x45]);
    expect(Commands.wake(), List.filled(12, 0));
  });

  test('feed splits into ESC J steps of at most 255 dots', () {
    expect(Commands.feed(80), [0x1B, 0x4A, 80]);
    expect(Commands.feed(300), [0x1B, 0x4A, 255, 0x1B, 0x4A, 45]);
    expect(Commands.feed(0), isEmpty);
  });
}
