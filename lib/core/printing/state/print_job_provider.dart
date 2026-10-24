import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peripage_app/core/device/data/device_repo_impl.dart';
import 'package:peripage_app/core/device/domain/device_settings.dart';
import 'package:peripage_app/core/device/state/device_provider.dart';
import 'package:peripage_app/core/history/state/history_provider.dart';
import 'package:peripage_app/core/printing/data/print_repo_impl.dart';
import 'package:peripage_app/core/printing/domain/print_cancelled_exception.dart';
import 'package:peripage_app/core/printing/domain/print_job_control.dart';
import 'package:peripage_app/core/printing/domain/print_job_entity.dart';
import 'package:peripage_app/core/printing/domain/print_progress.dart';
import 'package:peripage_app/core/printing/domain/print_time_estimator.dart';
import 'package:peripage_app/core/printing/domain/print_usecases.dart';

final class PrintJobState {
  /// Non-null while a job is running.
  final PrintProgress? progress;

  /// Estimated progress on paper, refreshed several times a second while running.
  final PrintEstimate? estimate;

  /// True between pressing Cancel and the job actually stopping.
  final bool cancelling;
  final String? error;

  /// The last job that finished, for a short confirmation. Check [PrintProgress.confirmed].
  final PrintProgress? finished;
  final bool cancelled;

  const PrintJobState({
    this.progress,
    this.estimate,
    this.cancelling = false,
    this.error,
    this.finished,
    this.cancelled = false,
  });

  bool get isRunning => progress != null;
}

/// The one active print job. App-wide so every screen can show its progress.
final class PrintJobNotifier extends Notifier<PrintJobState> {
  static const _tick = Duration(milliseconds: 250);

  PrintJobControl? _control;
  PrintTimeEstimator? _estimator;
  Timer? _ticker;

  @override
  PrintJobState build() {
    ref.onDispose(() => _ticker?.cancel());
    return const PrintJobState();
  }

  Future<void> start(PrintJobEntity job) async {
    if (state.isRunning) return;
    final device = ref.read(deviceProvider).valueOrNull;
    final deviceSettings = ref.read(deviceSettingsProvider).valueOrNull;
    final paper = deviceSettings?.paperType ?? PaperType.roll;
    final control = _control = PrintJobControl(autoContinue: deviceSettings?.autoContinueSheets ?? true);
    final repo = ref.read(printRepoProvider);
    final deviceRepo = ref.read(deviceRepoProvider);
    final pages = job.settings.pageIndices(job.draft.pageCount);

    final estimator = _estimator = PrintTimeEstimator(
      linesPerSecond: device == null ? null : await deviceRepo.printSpeed(device.name),
    );
    state = PrintJobState(
      progress: PrintProgress(
        fileName: job.draft.fileName,
        sentBytes: 0,
        totalBytes: 1,
        page: 1,
        pageCount: pages.length,
        copy: 1,
        copies: job.settings.copies,
      ),
    );
    _ticker = Timer.periodic(_tick, (_) => _refreshEstimate());

    // Once a page reached the printer the job belongs in history, whatever happens afterwards.
    var anyPageSent = false;
    Future<void> record() async {
      final firstPage = await repo.renderPage(job.draft, job.settings, pages.first, device!.widthDots);
      await ref.read(historyProvider.notifier).record(job, device.name, firstPage);
    }

    try {
      PrintProgress? result;
      await for (final progress in PrintJobUseCase(repo).call(job, device, paper, control)) {
        estimator.update(progress);
        if (progress.phase == PrintPhase.done) {
          result = progress;
        } else {
          // Waiting for a further sheet or for the printer means at least one page went out.
          anyPageSent |= progress.page > 1 || progress.phase == PrintPhase.printing;
          state = PrintJobState(progress: progress, estimate: estimator.estimate(), cancelling: control.cancelled);
        }
      }
      _stopTicker();
      await _calibrate(estimator, result, device?.name);
      await record();
      state = PrintJobState(finished: result);
    } on PrintCancelledException catch (e) {
      _stopTicker();
      // A half-sent raster frame would swallow the next job's bytes; reconnecting makes the printer drop it.
      if (e.midPage) await ref.read(deviceProvider.notifier).reconnect();
      if (e.pagesSent) await _tryRecord(record);
      state = const PrintJobState(cancelled: true);
    } catch (e) {
      _stopTicker();
      if (anyPageSent) await _tryRecord(record);
      state = PrintJobState(error: e is StateError ? e.message : e.toString());
    } finally {
      _control = null;
      _estimator = null;
    }
  }

  /// Stops sending (or waiting for the printer / the next sheet) at the next opportunity.
  void cancel() {
    final control = _control;
    if (!state.isRunning || control == null || control.cancelled) return;
    control.cancel();
    state = PrintJobState(progress: state.progress, estimate: state.estimate, cancelling: true);
  }

  /// "Ask before continuing": the next sheet is in, go on.
  void continueWithNextSheet() => _control?.proceed();

  void dismiss() => state = const PrintJobState();

  void _refreshEstimate() {
    final estimator = _estimator;
    if (estimator == null || !state.isRunning) return;
    state = PrintJobState(progress: state.progress, estimate: estimator.estimate(), cancelling: state.cancelling);
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// Blends the speed measured on a confirmed job into the stored one, so estimates converge on the real printer.
  Future<void> _calibrate(PrintTimeEstimator estimator, PrintProgress? result, String? deviceName) async {
    final measured = estimator.measuredLinesPerSecond();
    if (measured == null || deviceName == null || !(result?.confirmed ?? false)) return;
    final blended = (estimator.linesPerSecond + measured) / 2;
    try {
      await ref.read(deviceRepoProvider).savePrintSpeed(deviceName, blended);
    } catch (_) {
      // A missed calibration only affects the next estimate.
    }
  }

  static Future<void> _tryRecord(Future<void> Function() record) async {
    try {
      await record();
    } catch (_) {
      // History is a convenience; never mask the real outcome.
    }
  }
}

final printJobProvider = NotifierProvider<PrintJobNotifier, PrintJobState>(PrintJobNotifier.new);
