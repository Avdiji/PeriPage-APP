import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peripage_app/config/adaptives.dart';
import 'package:peripage_app/config/constants.dart';
import 'package:peripage_app/config/theme.dart';
import 'package:peripage_app/core/device/domain/device_settings.dart';
import 'package:peripage_app/core/device/state/device_provider.dart';
import 'package:peripage_app/core/device/state/printer_status_provider.dart';
import 'package:peripage_app/core/printing/domain/print_job_entity.dart';
import 'package:peripage_app/core/printing/domain/print_progress.dart';
import 'package:peripage_app/core/printing/domain/print_settings.dart';
import 'package:peripage_app/core/printing/state/draft_provider.dart';
import 'package:peripage_app/core/printing/state/print_job_provider.dart';
import 'package:peripage_app/presentation/common/widgets/fade_slide_in.dart';
import 'package:peripage_app/presentation/common/widgets/glass/accent_button.dart';
import 'package:peripage_app/presentation/common/widgets/glass/glass_panel.dart';
import 'package:peripage_app/presentation/common/widgets/glass/glass_segmented.dart';
import 'package:peripage_app/presentation/common/widgets/glass/status_pill.dart';
import 'package:peripage_app/presentation/common/widgets/screen_header.dart';
import 'package:peripage_app/presentation/common/widgets/setting_row.dart';
import 'package:peripage_app/presentation/common/widgets/thermal_preview.dart';

class DraftScreen extends ConsumerWidget {
  const DraftScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(printerStatusProvider).status;
    final desktop = Adaptives.isDesktop(context);
    final header = ScreenHeader(title: 'Draft', trailing: StatusPill(status: status));

    return desktop ? _DesktopDraft(header: header) : _MobileDraft(header: header);
  }
}

/// Prints the current draft with its settings. Also bound to Ctrl+P in the shell.
void printDraft(WidgetRef ref) {
  final draft = ref.read(draftProvider);
  if (draft.draft == null) return;
  ref.read(printJobProvider.notifier).start(PrintJobEntity(draft: draft.draft!, settings: draft.settings));
}

class _MobileDraft extends StatelessWidget {
  const _MobileDraft({required this.header});

  final Widget header;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Styling.pagePadding, 20, Styling.pagePadding, Adaptives.mobileNavInset),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final roomy = constraints.maxHeight > 700;
          final children = [
            header,
            FadeSlideIn(delay: FadeSlideIn.stagger(0), child: const _FileBar()),
            const SizedBox(height: Styling.gap),
            if (roomy) const Expanded(child: _PreviewArea()) else const SizedBox(height: 300, child: _PreviewArea()),
            const _PageNavigator(),
            const SizedBox(height: Styling.gap),
            FadeSlideIn(delay: FadeSlideIn.stagger(1), child: const _CompactSettings()),
            const SizedBox(height: Styling.gap),
            FadeSlideIn(delay: FadeSlideIn.stagger(2), child: const _PrintButton()),
          ];
          return roomy
              ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)
              : ListView(children: children);
        },
      ),
    );
  }
}

class _DesktopDraft extends StatelessWidget {
  const _DesktopDraft({required this.header});

  final Widget header;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeSlideIn(delay: FadeSlideIn.stagger(0), child: const _FileBar()),
                    const SizedBox(height: Styling.gap),
                    const Expanded(child: _DropArea(child: _PreviewArea())),
                    const _PageNavigator(),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              SizedBox(
                width: 340,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FadeSlideIn(delay: FadeSlideIn.stagger(1), child: const _PagesCard()),
                      FadeSlideIn(delay: FadeSlideIn.stagger(2), child: const _ImageCard()),
                      FadeSlideIn(delay: FadeSlideIn.stagger(3), child: const _PrinterCard()),
                      const SizedBox(height: 4),
                      FadeSlideIn(delay: FadeSlideIn.stagger(4), child: const _PrintButton()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FileBar extends ConsumerWidget {
  const _FileBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(draftProvider);
    final draft = state.draft;
    final colors = context.glass;
    final desktop = Adaptives.isDesktop(context);

    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          GlassPanel(
            strong: true,
            radius: 10,
            padding: const EdgeInsets.all(9),
            child: Text(
              draft == null ? '+' : (draft.isPdf ? 'PDF' : 'IMG'),
              style: TextStyle(color: colors.accent, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.fast,
              child: Column(
                key: ValueKey(draft?.path),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(draft?.fileName ?? 'No file selected', maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    draft == null ? 'Images or PDF' : '${draft.pageCount} page${draft.pageCount == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          TextLink(
            state.picking ? 'Opening…' : (draft == null || desktop ? 'Choose file…' : 'Change'),
            onTap: state.picking ? null : () => ref.read(draftProvider.notifier).pick(),
          ),
        ],
      ),
    );
  }
}

class _DropArea extends ConsumerWidget {
  const _DropArea({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.glass;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Styling.radius),
        border: Border.all(color: colors.line, width: 1.5),
      ),
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Expanded(child: child),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Ctrl+O to open a file · Ctrl+P to print', style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _PreviewArea extends ConsumerWidget {
  const _PreviewArea();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDraft = ref.watch(draftProvider.select((s) => s.draft != null));
    final preview = ref.watch(previewProvider);

    if (!hasDraft) {
      return GestureDetector(
        onTap: () => ref.read(draftProvider.notifier).pick(),
        behavior: HitTestBehavior.opaque,
        child: const EmptyPreview(hint: 'Choose an image or PDF to print'),
      );
    }
    return Stack(
      children: [
        Positioned.fill(child: ThermalPreview(bitmap: preview.valueOrNull)),
        if (preview.isLoading)
          const Positioned(top: 24, right: 0, left: 0, child: Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5)))),
        if (preview.hasError) Center(child: EmptyPreview(hint: preview.error.toString())),
      ],
    );
  }
}

class _PageNavigator extends ConsumerWidget {
  const _PageNavigator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(draftProvider);
    final draft = state.draft;
    if (draft == null || draft.pageCount < 2) return const SizedBox.shrink();

    final page = state.settings.currentPage;
    void go(int p) => ref.read(draftProvider.notifier).update(state.settings.copyWith(currentPage: p));

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextLink('‹', onTap: page > 0 ? () => go(page - 1) : null),
          const SizedBox(width: 12),
          Text('Page ${page + 1} of ${draft.pageCount}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 12),
          TextLink('›', onTap: page < draft.pageCount - 1 ? () => go(page + 1) : null),
        ],
      ),
    );
  }
}

/// Mobile: one card with the most used settings.
class _CompactSettings extends ConsumerWidget {
  const _CompactSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(draftProvider);
    final isPdf = state.draft?.isPdf ?? false;
    return GlassPanel(
      child: Column(
        children: [
          if (isPdf) const _PagesRow(),
          const _DitherRow(),
          const _DensityRow(),
          const _CopiesRow(),
        ],
      ),
    );
  }
}

class _PagesCard extends ConsumerWidget {
  const _PagesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPdf = ref.watch(draftProvider.select((s) => s.draft?.isPdf ?? false));
    return AnimatedSize(
      duration: Motion.medium,
      child: isPdf
          ? const Padding(
              padding: EdgeInsets.only(bottom: Styling.gap),
              child: GlassPanel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [SectionLabel('Pages'), _PagesRow()]),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: Styling.gap),
      child: GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [SectionLabel('Image'), _DitherRow(), _ScaleRow(), _RotateRow()],
        ),
      ),
    );
  }
}

class _PrinterCard extends StatelessWidget {
  const _PrinterCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: Styling.gap),
      child: GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [SectionLabel('Printer'), _DensityRow(), _CopiesRow()],
        ),
      ),
    );
  }
}

// ----- SETTING ROWS -----

abstract class _SettingsRow extends ConsumerWidget {
  const _SettingsRow();

  Widget buildRow(BuildContext context, PrintSettings settings, ValueChanged<PrintSettings> update, DraftState state);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(draftProvider);
    return buildRow(context, state.settings, ref.read(draftProvider.notifier).update, state);
  }
}

class _PagesRow extends _SettingsRow {
  const _PagesRow();

  @override
  Widget buildRow(BuildContext context, PrintSettings settings, ValueChanged<PrintSettings> update, DraftState state) {
    final pageCount = state.draft?.pageCount ?? 1;
    final selected = settings.pageIndices(pageCount);
    final summary = selected.isEmpty
        ? 'No valid page — use numbers from 1 to $pageCount'
        : 'Prints ${selected.length} of $pageCount page${pageCount == 1 ? '' : 's'}: ${_compact(selected)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingRow(
          label: 'Print',
          child: GlassSegmented<PageSelection>(
            options: PageSelection.values,
            selected: settings.pages,
            labelOf: (p) => p.label,
            onChanged: (p) => update(settings.copyWith(pages: p)),
          ),
        ),
        if (pageCount > 1)
          _PageChips(
            pageCount: pageCount,
            selected: selected.toSet(),
            onToggle: (page) {
              final next = selected.toSet();
              if (!next.remove(page)) next.add(page);
              final sorted = next.toList()..sort();
              update(
                sorted.length == pageCount
                    ? settings.copyWith(pages: PageSelection.all)
                    : settings.copyWith(
                        pages: PageSelection.custom,
                        pageSpec: sorted.isEmpty ? '' : _compact(sorted, dash: '-'),
                        currentPage: page,
                      ),
              );
            },
          ),
        AnimatedSize(
          duration: Motion.medium,
          curve: Curves.easeInOutCubic,
          child: settings.pages != PageSelection.custom
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PageSpecField(value: settings.pageSpec, onChanged: (s) => update(settings.copyWith(pageSpec: s))),
                      const SizedBox(height: 6),
                      Text(
                        summary,
                        style: TextStyle(fontSize: 12, color: selected.isEmpty ? context.glass.accent : context.glass.muted),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  /// 0-based [0,1,2,4] → "1–3, 5" (or "1-3, 5" with [dash] for an editable page list).
  static String _compact(List<int> pages, {String dash = '–'}) {
    final parts = <String>[];
    var start = pages.first;
    var prev = start;
    void flush() => parts.add(start == prev ? '${start + 1}' : '${start + 1}$dash${prev + 1}');
    for (final p in pages.skip(1)) {
      if (p == prev + 1) {
        prev = p;
        continue;
      }
      flush();
      start = prev = p;
    }
    flush();
    return parts.join(', ');
  }
}

/// One toggle chip per page; selected pages are filled.
class _PageChips extends StatelessWidget {
  const _PageChips({required this.pageCount, required this.selected, required this.onToggle});

  final int pageCount;
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.glass;
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 112),
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < pageCount; i++)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onToggle(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      constraints: const BoxConstraints(minWidth: 34),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected.contains(i) ? colors.accent : colors.line,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '${i + 1}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected.contains(i) ? colors.onAccent : colors.muted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Free-form page list, e.g. "2" or "1-3, 5". Follows outside changes (page chips) unless being edited.
class _PageSpecField extends StatefulWidget {
  const _PageSpecField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_PageSpecField> createState() => _PageSpecFieldState();
}

class _PageSpecFieldState extends State<_PageSpecField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(_PageSpecField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.glass;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Styling.radiusSmall),
      borderSide: BorderSide(color: colors.line),
    );
    return TextField(
      controller: _controller,
      focusNode: _focus,
      onChanged: widget.onChanged,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: colors.line,
        hintText: 'e.g. 2  or  1-3, 5',
        hintStyle: TextStyle(color: colors.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: BorderSide(color: colors.accent)),
      ),
    );
  }
}

class _DitherRow extends _SettingsRow {
  const _DitherRow();

  @override
  Widget buildRow(BuildContext context, PrintSettings settings, ValueChanged<PrintSettings> update, DraftState state) {
    return SettingRow(
      label: 'Dither',
      child: GlassSegmented<Dither>(
        options: Dither.values,
        selected: settings.dither,
        labelOf: (d) => d.label,
        onChanged: (d) => update(settings.copyWith(dither: d)),
      ),
    );
  }
}

class _ScaleRow extends _SettingsRow {
  const _ScaleRow();

  @override
  Widget buildRow(BuildContext context, PrintSettings settings, ValueChanged<PrintSettings> update, DraftState state) {
    return SettingRow(
      label: 'Scale',
      child: GlassSegmented<ScaleMode>(
        options: ScaleMode.values,
        selected: settings.scale,
        labelOf: (s) => s.label,
        onChanged: (s) => update(settings.copyWith(scale: s)),
      ),
    );
  }
}

class _RotateRow extends _SettingsRow {
  const _RotateRow();

  @override
  Widget buildRow(BuildContext context, PrintSettings settings, ValueChanged<PrintSettings> update, DraftState state) {
    return SettingRow(
      label: 'Rotate',
      child: GlassSegmented<int>(
        options: const [0, 1, 2, 3],
        selected: settings.rotation,
        labelOf: (r) => '${r * 90}°',
        onChanged: (r) => update(settings.copyWith(rotation: r)),
      ),
    );
  }
}

class _DensityRow extends _SettingsRow {
  const _DensityRow();

  @override
  Widget buildRow(BuildContext context, PrintSettings settings, ValueChanged<PrintSettings> update, DraftState state) {
    return SettingRow(
      label: 'Density',
      child: GlassSegmented<Density>(
        options: Density.values,
        selected: Density.values[settings.density.clamp(0, Density.values.length - 1)],
        labelOf: (d) => d.label,
        onChanged: (d) => update(settings.copyWith(density: d.index)),
      ),
    );
  }
}

class _CopiesRow extends _SettingsRow {
  const _CopiesRow();

  @override
  Widget buildRow(BuildContext context, PrintSettings settings, ValueChanged<PrintSettings> update, DraftState state) {
    return SettingRow(
      label: 'Copies',
      child: _Stepper(value: settings.copies, min: 1, max: 99, onChanged: (c) => update(settings.copyWith(copies: c))),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.min, required this.max, required this.onChanged});

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.glass;
    Widget button(String label, int? next) => MouseRegion(
      cursor: next == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        // Opaque: the whole padded box is tappable, not just the glyph's pixels.
        behavior: HitTestBehavior.opaque,
        onTap: next == null ? null : () => onChanged(next),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Text(label, style: TextStyle(color: next == null ? colors.muted.withValues(alpha: .4) : colors.ink)),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: colors.line, borderRadius: BorderRadius.circular(Styling.radiusSmall)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button('–', value > min ? value - 1 : null),
          Container(
            constraints: const BoxConstraints(minWidth: 30),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(color: colors.glassStrong, borderRadius: BorderRadius.circular(8)),
            child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          button('+', value < max ? value + 1 : null),
        ],
      ),
    );
  }
}

class _PrintButton extends ConsumerWidget {
  const _PrintButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(draftProvider);
    final connected = ref.watch(deviceProvider).valueOrNull != null;
    final running = ref.watch(printJobProvider).isRunning;
    final draft = state.draft;

    final pages = draft == null ? 0 : state.settings.pageIndices(draft.pageCount).length;
    final job = ref.watch(printJobProvider.select((s) => s.progress));
    final label = switch ((draft, connected, running)) {
      (_, _, true) => switch (job?.phase) {
        PrintPhase.waitingForPaper || PrintPhase.paperReady => 'Waiting for the next sheet…',
        _ when (job?.pageCount ?? 1) > 1 => 'Printing page ${job!.page} of ${job.pageCount}…',
        _ => 'Printing…',
      },
      (null, _, _) => 'Print',
      (_, false, _) => 'No printer connected',
      _ when pages == 0 => 'No valid pages',
      _ => pages > 1 ? 'Print · $pages pages' : 'Print',
    };

    final cancelling = ref.watch(printJobProvider.select((s) => s.cancelling));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccentButton(
          label: label,
          loading: running,
          onPressed: draft != null && connected && pages > 0 ? () => printDraft(ref) : null,
        ),
        AnimatedSize(
          duration: Motion.medium,
          curve: Curves.easeInOutCubic,
          child: running
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: AccentButton(
                    label: cancelling ? 'Cancelling…' : 'Cancel print',
                    ghost: true,
                    loading: cancelling,
                    onPressed: () => ref.read(printJobProvider.notifier).cancel(),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
