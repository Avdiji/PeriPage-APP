import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peripage_app/core/device/data/device_repo_impl.dart';
import 'package:peripage_app/core/device/domain/device_entity.dart';
import 'package:peripage_app/core/device/domain/device_settings.dart';
import 'package:peripage_app/core/device/domain/device_usecases.dart';

/// The connected printer, or null. Reconnects to the saved printer on start.
final class DeviceNotifier extends AsyncNotifier<DeviceEntity?> {
  @override
  FutureOr<DeviceEntity?> build() async {
    try {
      return await ReconnectSavedDeviceUseCase(ref.read(deviceRepoProvider)).call();
    } catch (_) {
      return null; // printer off or out of range — the UI offers to connect manually
    }
  }

  Future<void> connect(DeviceCandidate candidate) async {
    ref.read(connectingIdProvider.notifier).state = candidate.id;
    state = const AsyncLoading();
    try {
      state = await AsyncValue.guard(() => ConnectDeviceUseCase(ref.read(deviceRepoProvider)).call(candidate));
    } finally {
      ref.read(connectingIdProvider.notifier).state = null;
    }
    ref.invalidate(savedDeviceProvider);
  }

  Future<void> disconnect() async {
    await ref.read(deviceRepoProvider).disconnect();
    state = const AsyncData(null);
  }

  /// The link dropped (printer switched off, out of range, auto power-off). Clears the device so the whole UI
  /// shows "Disconnected", then tries once to reconnect without a loading state.
  Future<void> connectionLost() async {
    if (state.valueOrNull == null || _recovering) return;
    _recovering = true;
    final saved = await ref.read(deviceRepoProvider).savedDevice();
    await ref.read(deviceRepoProvider).disconnect();
    state = const AsyncData(null);
    try {
      if (saved != null) {
        final device = await ConnectDeviceUseCase(ref.read(deviceRepoProvider)).call(saved);
        state = AsyncData(device);
      }
    } catch (_) {
      // Stay disconnected; the Device view offers "Connect".
    } finally {
      _recovering = false;
    }
  }

  bool _recovering = false;

  /// Feeds paper: the next sheet / fold / label for page-wise paper, a short strip on rolls.
  Future<void> feedPaper() async {
    final paper = ref.read(deviceSettingsProvider).valueOrNull?.paperType ?? PaperType.roll;
    await ref.read(deviceRepoProvider).feedPaper(paper);
  }

  /// Drops and re-opens the link to the saved printer, e.g. to discard a half-received job.
  Future<void> reconnect() async {
    final saved = await ref.read(deviceRepoProvider).savedDevice();
    await disconnect();
    if (saved != null) await connect(saved);
  }

  void updateBattery(int battery) {
    final device = state.valueOrNull;
    if (device != null && device.battery != battery) state = AsyncData(device.copyWith(battery: battery));
  }
}

final deviceProvider = AsyncNotifierProvider<DeviceNotifier, DeviceEntity?>(DeviceNotifier.new);

/// Id of the printer a connect is in progress for, so lists can show a spinner on that row.
final connectingIdProvider = StateProvider<String?>((Ref ref) => null);

/// The remembered printer. Null means first run → show setup.
final savedDeviceProvider = FutureProvider<DeviceCandidate?>((Ref ref) {
  return ref.read(deviceRepoProvider).savedDevice();
});

/// Printers in range. Scans once and keeps the result across tab switches; rescan with
/// `ref.invalidate(discoveryProvider)`.
final discoveryProvider = FutureProvider<List<DeviceCandidate>>((Ref ref) {
  return ref.read(deviceRepoProvider).discover();
});

final class DeviceSettingsNotifier extends AsyncNotifier<DeviceSettings> {
  @override
  FutureOr<DeviceSettings> build() => ref.read(deviceRepoProvider).loadSettings();

  Future<void> change(DeviceSettings settings) async {
    state = AsyncData(settings);
    final repo = ref.read(deviceRepoProvider);
    await repo.saveSettings(settings);
    await repo.applySettings(settings);
  }
}

final deviceSettingsProvider = AsyncNotifierProvider<DeviceSettingsNotifier, DeviceSettings>(
  DeviceSettingsNotifier.new,
);
