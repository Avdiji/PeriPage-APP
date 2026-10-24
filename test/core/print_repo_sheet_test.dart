import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:peripage_app/core/device/domain/device_entity.dart';
import 'package:peripage_app/core/device/domain/device_settings.dart';
import 'package:peripage_app/core/printing/data/print_repo_impl.dart';
import 'package:peripage_app/core/printing/domain/print_cancelled_exception.dart';
import 'package:peripage_app/core/printing/domain/print_job_control.dart';
import 'package:peripage_app/core/printing/domain/print_job_entity.dart';
import 'package:peripage_app/core/printing/domain/print_progress.dart';
import 'package:peripage_app/core/printing/domain/print_settings.dart';
import 'package:peripage_app/services/files/document_loader.dart';
import 'package:peripage_app/services/files/file_store.dart';
import 'package:peripage_app/services/transport/models/discovered_device_in.dart';
import 'package:peripage_app/services/transport/printer_client.dart';
import 'package:peripage_app/services/transport/printer_transport.dart';

/// Answers status queries from a script (repeating the last entry) and counts raster pages received.
final class _ScriptedPrinter implements PrinterTransport {
  _ScriptedPrinter(this.statusScript);

  final List<int> statusScript;
  final _incoming = StreamController<Uint8List>.broadcast();
  var _statusIndex = 0;
  var pagesReceived = 0;

  @override
  Future<void> write(Uint8List data) async {
    if (data.length == 3 && data[0] == 0x10 && data[2] == 0x40) {
      final reply = statusScript[_statusIndex.clamp(0, statusScript.length - 1)];
      _statusIndex++;
      scheduleMicrotask(() => _incoming.add(Uint8List.fromList([reply])));
    } else if (data.length > 4 && data[0] == 0x10 && data[2] == 0xFE && data[3] == 0x01) {
      pagesReceived++; // start-of-page frame
    } else if (data.length == 5 && data[2] == 0x10) {
      scheduleMicrotask(() => _incoming.add(Uint8List.fromList([0x4F, 0x4B]))); // density ack
    }
  }

  @override
  Stream<Uint8List> get incoming => _incoming.stream;
  @override
  bool get isConnected => true;
  @override
  Future<void> connect(DiscoveredDeviceIn device) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<List<DiscoveredDeviceIn>> discover() async => const [];
}

void main() {
  late String imagePath;
  const device = DeviceEntity(id: 'x', name: 'PPG_A40', widthDots: 64, dpi: 203);

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('peripage_test');
    imagePath = '${dir.path}${Platform.pathSeparator}page.png';
    await File(imagePath).writeAsBytes(img.encodePng(img.Image(width: 64, height: 32)));
  });

  PrintJobEntity job({int copies = 2}) => PrintJobEntity(
    draft: DraftEntity(path: imagePath, fileName: 'page.png', isPdf: false, pageCount: 1),
    settings: PrintSettings(copies: copies),
  );

  test('single sheets: waits for the next sheet, then continues automatically', () async {
    // sheet 1 in | printing, ejected | no sheet, no sheet, sheet 2 in | printing, ejected
    final printer = _ScriptedPrinter([0x00, 0x01, 0x04, 0x04, 0x04, 0x00, 0x01, 0x04]);
    final repo = PrintRepoImpl(FileStore(), DocumentLoader(), PrinterClient(printer));

    final phases = await repo
        .print(job(), device, PaperType.sheet, PrintJobControl(autoContinue: true))
        .map((p) => p.phase)
        .distinct()
        .toList();

    expect(printer.pagesReceived, 2);
    expect(phases, containsAllInOrder([PrintPhase.sending, PrintPhase.waitingForPaper, PrintPhase.sending, PrintPhase.done]));
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('single sheets, ask mode: cancelling at the prompt stops before the second page', () async {
    final printer = _ScriptedPrinter([0x00, 0x01, 0x04, 0x00]);
    final repo = PrintRepoImpl(FileStore(), DocumentLoader(), PrinterClient(printer));
    final control = PrintJobControl(autoContinue: false);

    final events = repo.print(job(), device, PaperType.sheet, control);
    Object? error;
    try {
      await for (final p in events) {
        if (p.phase == PrintPhase.paperReady) control.cancel();
      }
    } catch (e) {
      error = e;
    }

    expect(printer.pagesReceived, 1);
    expect(error, isA<PrintCancelledException>().having((e) => e.pagesSent, 'pagesSent', isTrue));
  }, timeout: const Timeout(Duration(seconds: 30)));
}
