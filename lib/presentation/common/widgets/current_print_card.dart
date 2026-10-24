import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peripage_app/config/theme.dart';
import 'package:peripage_app/core/device/state/printer_status_provider.dart';
import 'package:peripage_app/core/printing/domain/print_progress.dart';
import 'package:peripage_app/core/printing/domain/print_time_estimator.dart';
import 'package:peripage_app/core/printing/state/print_job_provider.dart';
import 'package:peripage_app/presentation/common/widgets/glass/glass_panel.dart';
import 'package:peripage_app/presentation/common/widgets/glass/progress_line.dart';
import 'package:peripage_app/presentation/common/widgets/glass/status_pill.dart';
import 'package:peripage_app/presentation/common/widgets/setting_row.dart';

/// One line describing what the job is doing right now.
String jobHeadline(PrintProgress p) => switch (p.phase) {
  PrintPhase.waitingForPaper => 'Insert sheet ${p.page} of ${p.pageCount}',
  PrintPhase.paperReady => 'Sheet ${p.page} is in — continue when ready',
  _ => p.pageCount > 1 ? 'Printing page ${p.page} of ${p.pageCount}' : 'Printing',
};

/// The detail line under the progress bar: time left on paper, or what the job is waiting for.
String jobDetail(PrintProgress p, PrintEstimate? estimate) => switch (p.phase) {
  PrintPhase.waitingForPaper => 'Paused — printing continues once the next sheet is in.',
  PrintPhase.paperReady => 'Paused — waiting for you to continue.',
  _ => [
    remainingLabel(estimate?.remaining),
    if (p.copies > 1) 'copy ${p.copy} of ${p.copies}',
  ].join(' · '),
};

/// "about 12 s left", "about 1 min 20 s left", or "Finishing…" for the last moments.
String remainingLabel(Duration? remaining) {
  if (remaining == null) return 'Estimating…';
  final seconds = remaining.inSeconds;
  if (seconds < 2) return 'Finishing…';
  if (seconds < 60) return 'about $seconds s left';
  return 'about ${seconds ~/ 60} min ${seconds % 60} s left';
}

/// Status of the printer and, during a job, which phase it is in with its progress.
class CurrentPrintCard extends ConsumerWidget {
  const CurrentPrintCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(printerStatusProvider);
    final progress = view.progress;
    final colors = context.glass;

    return GlassPanel(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(
              progress == null ? 'Status' : 'Current print',
              trailing: progress == null ? null : const CancelPrintLink(),
            ),
            if (progress == null)
              Row(
                children: [
                  StatusDot(status: view.status),
                  const SizedBox(width: 10),
                  Text(view.status.label),
                  if (view.status.isProblem) ...[
                    const Spacer(),
                    Text('Check the printer', style: TextStyle(color: colors.muted, fontSize: 12)),
                  ],
                ],
              )
            else ...[
              Text(progress.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(jobHeadline(progress), style: TextStyle(color: colors.muted, fontSize: 13)),
              const SizedBox(height: 12),
              // Estimated progress on paper (see PrintTimeEstimator), not the data transfer.
              ProgressLine(value: view.estimate?.fraction ?? 0),
              const SizedBox(height: 8),
              Text(jobDetail(progress, view.estimate), style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Cancel" while a job runs, "Cancelling…" once requested.
class CancelPrintLink extends ConsumerWidget {
  const CancelPrintLink({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cancelling = ref.watch(printJobProvider.select((s) => s.cancelling));
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: cancelling
          ? Text('Cancelling…', key: const ValueKey('cancelling'), style: TextStyle(fontSize: 13, color: context.glass.muted))
          : TextLink('Cancel', key: const ValueKey('cancel'), onTap: () => ref.read(printJobProvider.notifier).cancel()),
    );
  }
}

/// Compact version for the desktop sidebar. Tapping it is handled by the parent.
class MiniStatus extends ConsumerWidget {
  const MiniStatus({super.key, required this.deviceName});

  final String? deviceName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(printerStatusProvider);
    final colors = context.glass;
    final progress = view.progress;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: colors.line, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(deviceName ?? 'No printer', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              if (view.battery != null) Text('${view.battery}%', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              StatusDot(status: view.status),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  progress == null
                      ? view.status.label
                      : switch (progress.phase) {
                          PrintPhase.waitingForPaper => 'Insert sheet ${progress.page}',
                          PrintPhase.paperReady => 'Sheet ${progress.page} ready',
                          _ => progress.pageCount > 1
                              ? 'Printing ${progress.page}/${progress.pageCount} · ${_shortRemaining(view.estimate)}'
                              : 'Printing · ${_shortRemaining(view.estimate)}',
                        },
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 500),
            child: progress == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ProgressLine(value: view.estimate?.fraction ?? 0, height: 4),
                  ),
          ),
        ],
      ),
    );
  }

  static String _shortRemaining(PrintEstimate? estimate) {
    final seconds = estimate?.remaining?.inSeconds;
    if (seconds == null) return '…';
    if (seconds < 2) return 'almost done';
    return seconds < 60 ? '~$seconds s' : '~${(seconds / 60).ceil()} min';
  }
}
