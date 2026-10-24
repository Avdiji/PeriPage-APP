import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:peripage_app/services/protocol/printer_models.dart';
import 'package:peripage_app/services/protocol/reply_parser.dart';

Uint8List _b(List<int> v) => Uint8List.fromList(v);

void main() {
  test('OK ack', () {
    expect(ReplyParser.isOk(_b([0x4F, 0x4B])), isTrue);
    expect(ReplyParser.isOk(_b([0x00])), isFalse);
  });

  test('battery is the second byte', () {
    expect(ReplyParser.battery(_b([0x00, 82])), 82);
    expect(ReplyParser.battery(_b([0x00])), isNull);
  });

  test('status codes', () {
    expect(ReplyParser.status(_b([0x00])), RawPrinterState.idle);
    expect(ReplyParser.status(_b([0x04])), RawPrinterState.noPaper);
    expect(ReplyParser.status(_b([0x06])), RawPrinterState.noPaper); // seen on a PPG_A40 without paper
    expect(ReplyParser.status(_b([0x01])), RawPrinterState.busy);
    expect(ReplyParser.status(_b([0x05])), RawPrinterState.busy); // still printing while the sheet leaves
    expect(ReplyParser.status(_b([0x4F, 0x4B])), RawPrinterState.unknown); // stray "OK" ack
    expect(ReplyParser.status(_b([])), RawPrinterState.unknown);
  });

  test('text replies drop the OK ack and firmware suffix', () {
    expect(ReplyParser.text(_b(utf8.encode('A6OK'))), 'A6');
    expect(ReplyParser.firmware(_b(utf8.encode('V1.4.7_2203OK'))), 'V1.4.7');
  });

  test('model lookup', () {
    expect(PrinterModel.fromName('PeriPage_A6_3F21').widthDots, 384);
    expect(PrinterModel.fromName('PeriPage_A3_1234').widthDots, 576);
    expect(PrinterModel.fromName('PeriPage_A40').prefersCompressedRaster, isTrue);
    expect(PrinterModel.isPeriPage('PPG_P21_HD_1A02'), isTrue);
    expect(PrinterModel.isPeriPage('Headphones'), isFalse);
  });
}
