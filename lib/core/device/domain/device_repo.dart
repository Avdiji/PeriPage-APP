import 'package:peripage_app/core/device/domain/device_entity.dart';
import 'package:peripage_app/core/device/domain/device_settings.dart';
import 'package:peripage_app/core/device/domain/printer_status.dart';

abstract interface class DeviceRepo {
  Future<List<DeviceCandidate>> discover();

  /// Connects and reads model information.
  Future<DeviceEntity> connect(DeviceCandidate candidate);

  Future<void> disconnect();

  bool get isConnected;

  Future<int?> queryBattery();

  Future<PrinterStatus> queryStatus();

  Future<void> applySettings(DeviceSettings settings);

  /// Advances to the next sheet / fold / label, or feeds a short strip of roll paper.
  Future<void> feedPaper(PaperType paper);

  Future<DeviceCandidate?> savedDevice();

  Future<void> saveDevice(DeviceCandidate candidate);

  Future<DeviceSettings> loadSettings();

  /// Last measured print speed of [deviceName] in dot-lines per second, null before the first print.
  Future<double?> printSpeed(String deviceName);

  Future<void> savePrintSpeed(String deviceName, double linesPerSecond);

  Future<void> saveSettings(DeviceSettings settings);
}
