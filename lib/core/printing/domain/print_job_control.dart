import 'dart:async';

/// Lets the UI steer a running job: cancel it, or continue after the next sheet was inserted.
final class PrintJobControl {
  /// Continue as soon as the printer detects the next sheet, instead of waiting for [proceed].
  final bool autoContinue;

  PrintJobControl({required this.autoContinue});

  bool _cancelled = false;
  Completer<void>? _gate;

  bool get cancelled => _cancelled;

  /// Completes when the user continues (or cancels — check [cancelled] afterwards).
  Future<void> waitForUser() => _cancelled ? Future.value() : (_gate = Completer<void>()).future;

  void proceed() => _open();

  void cancel() {
    _cancelled = true;
    _open();
  }

  void _open() {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }
}
