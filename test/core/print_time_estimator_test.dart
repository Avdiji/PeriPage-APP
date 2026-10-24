import 'package:flutter_test/flutter_test.dart';
import 'package:peripage_app/core/printing/domain/print_progress.dart';
import 'package:peripage_app/core/printing/domain/print_time_estimator.dart';

void main() {
  var now = DateTime(2026);
  PrintTimeEstimator estimator() => PrintTimeEstimator(linesPerSecond: 100, clock: () => now);

  PrintProgress progress(PrintPhase phase, {int page = 1, int pages = 2}) => PrintProgress(
    fileName: 'f',
    sentBytes: 0,
    totalBytes: 1,
    page: page,
    pageCount: pages,
    copy: 1,
    copies: 1,
    phase: phase,
    pageLines: List.filled(pages, 1000),
  );

  setUp(() => now = DateTime(2026));

  test('progress follows print time, not the transfer', () {
    final e = estimator()..update(progress(PrintPhase.sending));
    now = now.add(const Duration(seconds: 5)); // 500 of 2000 lines
    final estimate = e.estimate();
    expect(estimate.fraction, closeTo(.25, .001));
    expect(estimate.remaining, const Duration(seconds: 15));
  });

  test('never runs ahead of the received page and pauses while waiting for a sheet', () {
    final e = estimator()..update(progress(PrintPhase.sending));
    now = now.add(const Duration(seconds: 30)); // way past page 1
    expect(e.estimate().fraction, closeTo(.49, .001)); // capped at 98 % of page 1

    e.update(progress(PrintPhase.waitingForPaper, page: 2));
    now = now.add(const Duration(minutes: 2)); // user takes their time
    expect(e.estimate().fraction, .5);
  });

  test('measures the real speed from a finished job, excluding sheet waits', () {
    final e = estimator()..update(progress(PrintPhase.sending));
    now = now.add(const Duration(seconds: 8));
    e.update(progress(PrintPhase.waitingForPaper, page: 2));
    now = now.add(const Duration(seconds: 60));
    e.update(progress(PrintPhase.sending, page: 2));
    now = now.add(const Duration(seconds: 8));
    e.update(progress(PrintPhase.done, page: 2));
    expect(e.measuredLinesPerSecond(), closeTo(125, .001)); // 2000 lines in 16 s of printing
  });
}
