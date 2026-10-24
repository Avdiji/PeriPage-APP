import 'dart:convert';
import 'dart:typed_data';

/// Raw printer state as reported by `10 FF 40`.
enum RawPrinterState { idle, busy, voiceMode, noPaper, lowBattery, overheated, unknown }

abstract final class ReplyParser {
  static bool isOk(Uint8List reply) => reply.length >= 2 && reply[0] == 0x4F && reply[1] == 0x4B;

  /// Battery reply is two bytes, the second one is the charge in percent.
  static int? battery(Uint8List reply) {
    if (reply.length < 2) return null;
    final value = reply[1];
    return value <= 100 ? value : null;
  }

  /// The status byte is a set of flags. Observed on a PPG_A40 printing one A4 sheet:
  /// `00` → (send) → `01` busy → `05` busy + paper sensor empty (sheet passing out) → `04` no paper (ejected).
  /// `06` = no paper + 0x02 (meaning unknown). So busy wins, then the most severe problem.
  static RawPrinterState status(Uint8List reply) {
    if (reply.isEmpty || isOk(reply)) return RawPrinterState.unknown;
    final flags = reply[0];
    if (flags == 0x00) return RawPrinterState.idle;
    if (flags == 0x03) return RawPrinterState.voiceMode;
    if (flags & 0x01 != 0) return RawPrinterState.busy;
    if (flags & 0x04 != 0) return RawPrinterState.noPaper;
    if (flags & 0x10 != 0) return RawPrinterState.overheated;
    if (flags & 0x08 != 0) return RawPrinterState.lowBattery;
    return RawPrinterState.busy;
  }

  /// Text replies (model, firmware, serial). Strips the trailing "OK" ack and control characters.
  static String? text(Uint8List reply) {
    if (reply.isEmpty) return null;
    final decoded = utf8.decode(reply, allowMalformed: true);
    final cleaned = decoded.replaceAll('OK', '').replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  /// Firmware replies look like `V1.4.7_xxxx`; keep the part before the underscore.
  static String? firmware(Uint8List reply) => text(reply)?.split('_').first;
}
