import 'dart:typed_data';

/// Byte builders for the PeriPage printer protocol.
///
/// Reverse engineered from the official app (com.ileadtek.peripage v6.10.12,
/// classes y0.h / y6.a). Every vendor command starts with `10 FF`.
abstract final class Commands {
  static const _p = 0x10;
  static const _f = 0xFF;

  // ----- QUERIES -----
  static Uint8List queryModel() => _bytes([_p, _f, 0x20, 0xF0]);
  static Uint8List queryFirmware() => _bytes([_p, _f, 0x20, 0xF1]);
  static Uint8List querySerial() => _bytes([_p, _f, 0x20, 0xF2]);
  static Uint8List queryBattery() => _bytes([_p, _f, 0x50, 0xF1]);
  static Uint8List queryStatus() => _bytes([_p, _f, 0x40]);

  // ----- SETTINGS -----
  /// Density level as sent by the original app for most models (0 light, 1 normal, 2 dark).
  static Uint8List setDensity(int level) => _bytes([_p, _f, 0x10, 0x00, level & 0xFF]);

  /// Paper type (0 continuous roll, 2 labels separated by gaps).
  static Uint8List setPaperType(int type) => _bytes([_p, _f, 0x10, 0x03, type & 0xFF]);

  /// Auto power-off in minutes (0 = never).
  static Uint8List setAutoOff(int minutes) => _bytes([_p, _f, 0x12, (minutes >> 8) & 0xFF, minutes & 0xFF]);

  // ----- PRINT JOB -----
  static Uint8List startJob() => _bytes([_p, _f, 0xFE, 0x01]);
  static Uint8List endJob() => _bytes([_p, _f, 0xFE, 0x45]);

  /// Twelve zero bytes the original app sends right before the raster data.
  static Uint8List wake() => Uint8List(12);

  /// Form feed: advance to the start of the next sheet, fold or label (`GS FF`).
  static Uint8List nextPage() => _bytes([0x1D, 0x0C]);

  /// Feed paper by [dots] (ESC J n), split into steps of at most 255.
  static Uint8List feed(int dots) {
    final out = BytesBuilder();
    var remaining = dots;
    while (remaining > 0) {
      final step = remaining > 255 ? 255 : remaining;
      out.add([0x1B, 0x4A, step]);
      remaining -= step;
    }
    return out.toBytes();
  }

  static Uint8List _bytes(List<int> values) => Uint8List.fromList(values);
}
