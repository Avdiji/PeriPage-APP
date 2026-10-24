import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peripage_app/config/constants.dart';
import 'package:peripage_app/config/theme.dart';
import 'package:peripage_app/core/device/state/device_provider.dart';
import 'package:peripage_app/core/printing/domain/print_progress.dart';
import 'package:peripage_app/core/printing/state/print_job_provider.dart';
import 'package:peripage_app/presentation/common/widgets/glass/accent_button.dart';
import 'package:peripage_app/presentation/common/widgets/glass/progress_line.dart';

/// Modal prompt over the whole app while a single-sheet job waits for its next sheet.
class NextSheetPrompt extends ConsumerWidget {
  const NextSheetPrompt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(printJobProvider);
    final progress = job.progress;
    final visible = progress != null &&
        (progress.phase == PrintPhase.waitingForPaper || progress.phase == PrintPhase.paperReady);

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: Motion.medium,
        curve: Motion.curve,
        child: visible ? _Prompt(progress: progress, cancelling: job.cancelling) : const SizedBox.shrink(),
      ),
    );
  }
}

class _Prompt extends ConsumerWidget {
  const _Prompt({required this.progress, required this.cancelling});

  final PrintProgress progress;
  final bool cancelling;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.glass;
    final ready = progress.phase == PrintPhase.paperReady;
    final autoContinue = ref.watch(deviceSettingsProvider).valueOrNull?.autoContinueSheets ?? true;
    final notifier = ref.read(printJobProvider.notifier);

    return Stack(
      children: [
        // Darkened, blurred backdrop so the prompt clearly sits above the app.
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: ColoredBox(color: Colors.black.withValues(alpha: .38)),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(Styling.pagePadding),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              // Solid surface instead of glass: this needs a decision, so it must read at a glance.
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(colors.glassStrong, colors.background),
                  borderRadius: BorderRadius.circular(Styling.radius + 4),
                  border: Border.all(color: colors.ink.withValues(alpha: .12)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: .28), blurRadius: 40, offset: const Offset(0, 16)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(ready ? Icons.check_circle_outline : Icons.note_add_outlined, size: 30, color: colors.accent),
                    const SizedBox(height: 14),
                    Text(
                      ready ? 'Sheet ${progress.page} is in' : 'Insert sheet ${progress.page} of ${progress.pageCount}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ready
                          ? 'Continue when the sheet sits straight in the feed slot.'
                          : 'Page ${progress.page - 1 < 1 ? 1 : progress.page - 1} is done. Place the next sheet in the feed slot.'
                                '${autoContinue ? ' Printing continues automatically.' : ''}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    if (!ready) ...[
                      const IndeterminateLine(),
                      const SizedBox(height: 6),
                      Center(child: Text('Waiting for paper…', style: Theme.of(context).textTheme.bodySmall)),
                      const SizedBox(height: 14),
                    ] else ...[
                      AccentButton(label: 'Continue printing', onPressed: notifier.continueWithNextSheet),
                      const SizedBox(height: 8),
                    ],
                    AccentButton(
                      label: cancelling ? 'Cancelling…' : 'Cancel print',
                      ghost: true,
                      loading: cancelling,
                      onPressed: notifier.cancel,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
