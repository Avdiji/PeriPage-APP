import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peripage_app/core/device/domain/device_entity.dart';
import 'package:peripage_app/core/device/domain/device_repo.dart';
import 'package:peripage_app/core/device/domain/device_settings.dart';
import 'package:peripage_app/core/device/domain/printer_status.dart';
import 'package:peripage_app/services/protocol/commands.dart';
import 'package:peripage_app/services/protocol/printer_models.dart';
import 'package:peripage_app/services/protocol/reply_parser.dart';
import 'package:peripage_app/services/storage/preferences_service.dart';
import 'package:peripage_app/services/transport/models/discovered_device_in.dart';
import 'package:peripage_app/services/transport/printer_client.dart';

final class DeviceRepoImpl implements DeviceRepo {
  final PrinterClient _client;
  final PreferencesService _prefs;
  const DeviceRepoImpl(this._client, this._prefs);

  @override
  Future<List<DeviceCandidate>> discover() async {
    final found = await _client.discover();
    return [for (final d in found) DeviceCandidate(id: d.id, name: d.name, detail: d.detail)];
  }

  @override
  Future<DeviceEntity> connect(DeviceCandidate candidate) async {
    await _client.connect(DiscoveredDeviceIn(id: candidate.id, name: candidate.name, detail: candidate.detail));

    // On Windows the candidate name is the COM port, so prefer what the printer reports.
    final reportedModel = ReplyParser.text(await _client.request(Commands.queryModel()));
    final firmware = ReplyParser.firmware(await _client.request(Commands.queryFirmware()));
    final serial = ReplyParser.text(await _client.request(Commands.querySerial()));

    final name = PrinterModel.isPeriPage(candidate.name) ? candidate.name : (reportedModel ?? candidate.name);
    final model = PrinterModel.fromName(name);
    return DeviceEntity(
      id: candidate.id,
      name: name,
      widthDots: model.widthDots,
      dpi: model.dpi,
      compressedRasterOnly: model.prefersCompressedRaster,
      firmware: firmware,
      serial: serial,
    );
  }

  @override
  Future<void> disconnect() => _client.disconnect();

  @override
  bool get isConnected => _client.isConnected;

  @override
  Future<int?> queryBattery() async => ReplyParser.battery(await _client.request(Commands.queryBattery()));

  @override
  Future<PrinterStatus> queryStatus() async {
    if (!_client.isConnected) return PrinterStatus.disconnected;
    final reply = await _client.request(Commands.queryStatus());
    return switch (ReplyParser.status(reply)) {
      RawPrinterState.idle => PrinterStatus.idle,
      RawPrinterState.busy || RawPrinterState.voiceMode => PrinterStatus.busy,
      RawPrinterState.noPaper => PrinterStatus.noPaper,
      RawPrinterState.lowBattery => PrinterStatus.lowBattery,
      RawPrinterState.overheated => PrinterStatus.overheated,
      // Older firmware does not answer the status query; being connected is the best we know.
      RawPrinterState.unknown => PrinterStatus.idle,
    };
  }

  @override
  Future<void> applySettings(DeviceSettings settings) async {
    if (!_client.isConnected) return;
    // The printer acks settings with "OK"; some firmware stays silent, so don't wait long.
    const ackTimeout = Duration(milliseconds: 600);
    await _client.request(Commands.setDensity(settings.density.index), timeout: ackTimeout);
    await _client.request(Commands.setPaperType(settings.paperType.code), timeout: ackTimeout);
    await _client.request(Commands.setAutoOff(settings.autoOffMinutes), timeout: ackTimeout);
  }

  @override
  Future<void> feedPaper(PaperType paper) =>
      _client.send(paper.advancesToNextPage ? Commands.nextPage() : Commands.feed(96));

  @override
  Future<DeviceCandidate?> savedDevice() async {
    final json = await _prefs.savedDevice();
    return json == null ? null : DeviceCandidate.fromJson(json);
  }

  @override
  Future<void> saveDevice(DeviceCandidate candidate) => _prefs.saveDevice(candidate.toJson());

  @override
  Future<DeviceSettings> loadSettings() async {
    final json = await _prefs.deviceSettings();
    return json == null ? const DeviceSettings() : DeviceSettings.fromJson(json);
  }

  @override
  Future<void> saveSettings(DeviceSettings settings) => _prefs.saveDeviceSettings(settings.toJson());

  @override
  Future<double?> printSpeed(String deviceName) => _prefs.printSpeed(deviceName);

  @override
  Future<void> savePrintSpeed(String deviceName, double linesPerSecond) =>
      _prefs.savePrintSpeed(deviceName, linesPerSecond);
}

final deviceRepoProvider = Provider<DeviceRepo>((Ref ref) {
  return DeviceRepoImpl(ref.watch(printerClientProvider), ref.watch(preferencesServiceProvider));
});
