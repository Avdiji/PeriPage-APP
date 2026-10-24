import 'package:peripage_app/core/device/domain/device_entity.dart';
import 'package:peripage_app/core/device/domain/device_repo.dart';

/// Connects, remembers the printer as default and pushes the saved settings to it.
final class ConnectDeviceUseCase {
  final DeviceRepo _repo;
  const ConnectDeviceUseCase(this._repo);

  Future<DeviceEntity> call(DeviceCandidate candidate) async {
    final device = await _repo.connect(candidate);
    await _repo.saveDevice(candidate);
    await _repo.applySettings(await _repo.loadSettings());
    final battery = await _repo.queryBattery();
    return device.copyWith(battery: battery);
  }
}

/// Reconnects to the saved printer if the user enabled it. Returns null if there is nothing to do.
final class ReconnectSavedDeviceUseCase {
  final DeviceRepo _repo;
  const ReconnectSavedDeviceUseCase(this._repo);

  Future<DeviceEntity?> call() async {
    final saved = await _repo.savedDevice();
    if (saved == null) return null;
    final settings = await _repo.loadSettings();
    if (!settings.reconnectOnStart) return null;
    return ConnectDeviceUseCase(_repo).call(saved);
  }
}
