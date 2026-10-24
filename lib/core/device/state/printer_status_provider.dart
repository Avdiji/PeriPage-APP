import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peripage_app/config/constants.dart';
import 'package:peripage_app/core/device/data/device_repo_impl.dart';
import 'package:peripage_app/core/device/domain/printer_status.dart';
import 'package:peripage_app/core/device/state/device_provider.dart';
import 'package:peripage_app/core/printing/domain/print_progress.dart';
import 'package:peripage_app/core/printing/domain/print_time_estimator.dart';
import 'package:peripage_app/core/printing/state/print_job_provider.dart';

final class PolledStatus {
  final PrinterStatus status;
  final int? battery;
  const PolledStatus(this.status, [this.battery]);
}

/// Polls status and battery while connected and not printing.
///
/// Connection loss is never shown here: it is reported to [deviceProvider], which clears the device (so the
/// status and the printer info always agree) and tries one quiet reconnect. A single failed poll is ignored.
final class PolledStatusNotifier extends Notifier<PolledStatus> {
  static const _failuresBeforeLost = 3;

  Timer? _timer;
  int _failures = 0;

  @override
  PolledStatus build() {
    final device = ref.watch(deviceProvider).valueOrNull;
    ref.onDispose(() => _timer?.cancel());
    _failures = 0;
    if (device == null) return const PolledStatus(PrinterStatus.disconnected);

    _timer = Timer.periodic(Timings.statusPoll, (_) => _poll());
    return PolledStatus(PrinterStatus.idle, device.battery);
  }

  /// Queries the printer right away (e.g. "Check paper") instead of waiting for the next tick.
  Future<PrinterStatus> refresh() async {
    await _poll();
    return state.status;
  }

  Future<void> _poll() async {
    if (ref.read(printJobProvider).isRunning) return;
    final repo = ref.read(deviceRepoProvider);
    if (!repo.isConnected) return _lost();
    try {
      final status = await repo.queryStatus();
      final battery = await repo.queryBattery();
      _failures = 0;
      state = PolledStatus(status, battery ?? state.battery);
    } catch (_) {
      if (++_failures >= _failuresBeforeLost || !repo.isConnected) _lost();
    }
  }

  void _lost() => ref.read(deviceProvider.notifier).connectionLost();
}

final polledStatusProvider = NotifierProvider<PolledStatusNotifier, PolledStatus>(PolledStatusNotifier.new);

final class PrinterStatusView {
  final PrinterStatus status;
  final int? battery;
  final PrintProgress? progress;
  final PrintEstimate? estimate;
  const PrinterStatusView(this.status, {this.battery, this.progress, this.estimate});
}

/// What the UI shows: connection state, polled status and the running job combined.
final printerStatusProvider = Provider<PrinterStatusView>((Ref ref) {
  final device = ref.watch(deviceProvider);
  final job = ref.watch(printJobProvider);
  final polled = ref.watch(polledStatusProvider);

  if (device.isLoading) return const PrinterStatusView(PrinterStatus.connecting);
  final connected = device.valueOrNull;
  if (connected == null) return const PrinterStatusView(PrinterStatus.disconnected);

  final battery = polled.battery ?? connected.battery;
  final progress = job.progress;
  if (progress != null) {
    // Transferring a page takes a second, printing it far longer, and the head starts with the first bytes —
    // so to the user both are "printing".
    final status = switch (progress.phase) {
      PrintPhase.waitingForPaper || PrintPhase.paperReady => PrinterStatus.waitingForPaper,
      _ => PrinterStatus.printing,
    };
    return PrinterStatusView(status, battery: battery, progress: progress, estimate: job.estimate);
  }
  return PrinterStatusView(polled.status, battery: battery);
});
