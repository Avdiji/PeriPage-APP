import 'dart:math' as math;

import 'package:peripage_app/core/printing/domain/print_progress.dart';

/// How far the job is on paper and how long it still takes, both estimated.
final class PrintEstimate {
  final double fraction;
  final Duration? remaining;

  const PrintEstimate(this.fraction, this.remaining);
}

/// Estimates physical print progress. The printer reports nothing while printing and receives a page in a
/// second or two but needs many more to print it, so progress is derived from time × print speed
/// (dot-lines per second). Waiting for the next sheet pauses the clock. After a confirmed job the measured
/// speed calibrates the next estimate.
final class PrintTimeEstimator {
  /// Fallback before the first measurement, roughly an A4 sheet in 20 s at 203 dpi.
  static const defaultLinesPerSecond = 115.0;

  PrintTimeEstimator({double? linesPerSecond, DateTime Function()? clock})
    : linesPerSecond = linesPerSecond ?? defaultLinesPerSecond,
      _clock = clock ?? DateTime.now;

  final double linesPerSecond;
  final DateTime Function() _clock;

  PrintProgress? _last;
  DateTime? _segmentStart;
  double _segmentStartLines = 0;
  double _linesDone = 0;
  Duration _printingTime = Duration.zero;

  void update(PrintProgress progress) {
    _last = progress;
    final now = _clock();
    switch (progress.phase) {
      case PrintPhase.sending || PrintPhase.printing:
        // The head starts with the first bytes, so the clock runs from then on.
        if (_segmentStart == null) {
          _segmentStart = now;
          _segmentStartLines = _linesDone;
        }
      case PrintPhase.waitingForPaper || PrintPhase.paperReady:
        _close(now);
        _linesDone = progress.linesBefore(progress.sequence).toDouble();
      case PrintPhase.done:
        _close(now);
        _linesDone = progress.totalLines.toDouble();
    }
  }

  PrintEstimate estimate() {
    final p = _last;
    if (p == null || p.totalLines == 0) return const PrintEstimate(0, null);
    final total = p.totalLines.toDouble();
    if (p.phase == PrintPhase.done) return const PrintEstimate(1, Duration.zero);

    var lines = _linesDone;
    final start = _segmentStart;
    if (start != null) {
      lines = _segmentStartLines + _clock().difference(start).inMilliseconds / 1000 * linesPerSecond;
      // Never ahead of what the printer has received, and never "done" before the printer says so.
      final received = p.phase == PrintPhase.printing ? total : p.linesBefore(p.sequence + 1).toDouble();
      lines = math.min(lines, math.min(received, total) * 0.98);
    }
    lines = math.max(lines, _linesDone);
    final remainingSeconds = (total - lines) / linesPerSecond;
    return PrintEstimate(lines / total, Duration(milliseconds: (remainingSeconds * 1000).round()));
  }

  /// Speed measured over this job (dot-lines per second), or null if too little was printed to tell.
  double? measuredLinesPerSecond() {
    final p = _last;
    if (p == null || p.phase != PrintPhase.done || _printingTime < const Duration(seconds: 3)) return null;
    return p.totalLines / (_printingTime.inMilliseconds / 1000);
  }

  void _close(DateTime now) {
    final start = _segmentStart;
    if (start == null) return;
    _printingTime += now.difference(start);
    _segmentStart = null;
  }
}
