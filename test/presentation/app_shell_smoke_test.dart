import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peripage_app/config/theme.dart';
import 'package:peripage_app/core/device/data/device_repo_impl.dart';
import 'package:peripage_app/core/device/domain/device_entity.dart';
import 'package:peripage_app/core/device/domain/device_repo.dart';
import 'package:peripage_app/core/device/domain/device_settings.dart';
import 'package:peripage_app/core/device/domain/printer_status.dart';
import 'package:peripage_app/core/history/data/history_repo_impl.dart';
import 'package:peripage_app/core/history/domain/history_entry.dart';
import 'package:peripage_app/core/history/domain/history_repo.dart';
import 'package:peripage_app/core/printing/data/print_repo_impl.dart';
import 'package:peripage_app/core/printing/domain/print_job_control.dart';
import 'package:peripage_app/core/printing/domain/print_job_entity.dart';
import 'package:peripage_app/core/printing/domain/print_progress.dart';
import 'package:peripage_app/core/printing/domain/print_repo.dart';
import 'package:peripage_app/core/printing/domain/print_settings.dart';
import 'package:peripage_app/presentation/device/setup_screen.dart';
import 'package:peripage_app/presentation/shell/app_shell.dart';

const _candidate = DeviceCandidate(id: 'AA:BB', name: 'PeriPage_A6_3F21', detail: 'AA:BB');
const _draft = DraftEntity(path: 'x.pdf', fileName: 'shipping-label.pdf', isPdf: true, pageCount: 2);

final class _FakeDeviceRepo implements DeviceRepo {
  @override
  Future<List<DeviceCandidate>> discover() async => [_candidate];
  @override
  Future<DeviceEntity> connect(DeviceCandidate candidate) async =>
      const DeviceEntity(id: 'AA:BB', name: 'PeriPage_A6_3F21', widthDots: 384, dpi: 203, battery: 82, firmware: 'V1.4.7');
  @override
  Future<void> disconnect() async {}
  @override
  bool get isConnected => true;
  @override
  Future<int?> queryBattery() async => 82;
  @override
  Future<PrinterStatus> queryStatus() async => PrinterStatus.idle;
  @override
  Future<void> applySettings(DeviceSettings settings) async {}
  @override
  Future<void> feedPaper(PaperType paper) async {}
  @override
  Future<DeviceCandidate?> savedDevice() async => _candidate;
  @override
  Future<void> saveDevice(DeviceCandidate candidate) async {}
  @override
  Future<DeviceSettings> loadSettings() async => const DeviceSettings();
  @override
  Future<void> saveSettings(DeviceSettings settings) async {}
  @override
  Future<double?> printSpeed(String deviceName) async => null;
  @override
  Future<void> savePrintSpeed(String deviceName, double linesPerSecond) async {}
}

final class _FakePrintRepo implements PrintRepo {
  @override
  Future<DraftEntity?> pickDraft() async => _draft;
  @override
  Future<PreviewBitmap> renderPage(DraftEntity draft, PrintSettings settings, int pageIndex, int widthDots) async =>
      PreviewBitmap(width: 8, height: 8, pixels: Uint8List(64));
  @override
  Stream<PrintProgress> print(PrintJobEntity job, DeviceEntity device, PaperType paper, PrintJobControl control) =>
      const Stream.empty();
}

final class _FakeHistoryRepo implements HistoryRepo {
  @override
  Future<List<HistoryEntry>> list() async => [
    for (var i = 0; i < 4; i++)
      HistoryEntry(
        id: '$i',
        draft: _draft,
        settings: const PrintSettings(copies: 2, rotation: 1),
        deviceName: 'PeriPage_A6_3F21',
        printedAt: DateTime.now().subtract(Duration(hours: 20 * i)),
      ),
  ];
  @override
  Future<HistoryEntry> record(PrintJobEntity job, String deviceName, PreviewBitmap firstPage) => throw UnimplementedError();
  @override
  Future<void> delete(HistoryEntry entry, {bool keepFile = false}) async {}
}

Widget _app(Widget home) => ProviderScope(
  overrides: [
    deviceRepoProvider.overrideWithValue(_FakeDeviceRepo()),
    printRepoProvider.overrideWithValue(_FakePrintRepo()),
    historyRepoProvider.overrideWithValue(_FakeHistoryRepo()),
  ],
  child: MaterialApp(theme: AppTheme.light, darkTheme: AppTheme.dark, home: home),
);

Future<void> _settle(WidgetTester tester) async {
  // Background animations repeat forever, so pump a fixed time instead of pumpAndSettle.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  for (final (name, size) in [('phone', const Size(390, 844)), ('desktop', const Size(1280, 800))]) {
    group(name, () {
      setUp(() {
        final binding = TestWidgetsFlutterBinding.ensureInitialized();
        binding.platformDispatcher.views.first.physicalSize = size;
        binding.platformDispatcher.views.first.devicePixelRatio = 1;
      });
      tearDown(() => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.resetPhysicalSize());

      testWidgets('all tabs render without layout errors', (tester) async {
        await tester.pumpWidget(_app(const AppShell()));
        await _settle(tester);
        expect(find.text('Draft'), findsWidgets);

        // Load a draft so the settings panels render too.
        await tester.tap(find.textContaining('Choose').first);
        await _settle(tester);
        expect(find.text('shipping-label.pdf'), findsWidgets);

        for (final tab in ['History', 'Device']) {
          await tester.tap(find.text(tab).last);
          await _settle(tester);
          expect(tester.takeException(), isNull, reason: '$tab tab threw');
        }
        expect(find.text('PeriPage_A6_3F21'), findsWidgets);
      });

      testWidgets('setup screen lists printers', (tester) async {
        await tester.pumpWidget(_app(const SetupScreen(firstRun: true)));
        await _settle(tester);
        expect(find.text('PeriPage_A6_3F21'), findsOneWidget);
        expect(find.text('Connect'), findsOneWidget);
      });
    });
  }
}
