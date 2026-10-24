import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peripage_app/config/adaptives.dart';
import 'package:peripage_app/config/constants.dart';
import 'package:peripage_app/config/theme.dart';
import 'package:peripage_app/core/device/domain/device_settings.dart';
import 'package:peripage_app/core/device/state/device_provider.dart';
import 'package:peripage_app/core/history/domain/history_entry.dart';
import 'package:peripage_app/core/history/domain/history_usecases.dart';
import 'package:peripage_app/core/history/state/history_provider.dart';
import 'package:peripage_app/core/printing/domain/print_settings.dart';
import 'package:peripage_app/core/printing/state/draft_provider.dart';
import 'package:peripage_app/core/printing/state/print_job_provider.dart';
import 'package:peripage_app/presentation/common/widgets/fade_slide_in.dart';
import 'package:peripage_app/presentation/common/widgets/glass/glass_panel.dart';
import 'package:peripage_app/presentation/common/widgets/screen_header.dart';
import 'package:peripage_app/presentation/common/widgets/thermal_preview.dart';
import 'package:peripage_app/presentation/shell/app_shell.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);
    final desktop = Adaptives.isDesktop(context);
    final all = history.valueOrNull ?? const <HistoryEntry>[];
    final entries = _query.isEmpty
        ? all
        : all.where((e) => e.draft.fileName.toLowerCase().contains(_query.toLowerCase())).toList();

    final header = ScreenHeader(
      title: 'History',
      trailing: all.isEmpty ? null : Text('${all.length} print${all.length == 1 ? '' : 's'}', style: Theme.of(context).textTheme.bodySmall),
    );

    final Widget body;
    if (history.isLoading) {
      body = const SizedBox.shrink();
    } else if (all.isEmpty) {
      body = const EmptyPreview(hint: 'Everything you print shows up here,\nready to print again with the same settings.');
    } else {
      body = desktop ? _DesktopTable(entries: entries) : _MobileList(entries: entries);
    }

    return Padding(
      padding: desktop
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(Styling.pagePadding, 20, Styling.pagePadding, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          if (desktop && all.isNotEmpty) ...[
            _SearchField(onChanged: (q) => setState(() => _query = q)),
            const SizedBox(height: Styling.gap + 4),
          ],
          Expanded(child: body),
        ],
      ),
    );
  }
}

// ----- ACTIONS -----

void _reprint(WidgetRef ref, HistoryEntry entry) {
  ref.read(printJobProvider.notifier).start(const ReprintUseCase().call(entry));
}

void _openAsDraft(WidgetRef ref, HistoryEntry entry) {
  ref.read(draftProvider.notifier).openFromHistory(entry);
  ref.read(shellTabProvider.notifier).state = ShellTab.draft;
}

void _delete(WidgetRef ref, HistoryEntry entry) {
  final inDraft = ref.read(draftProvider).draft?.path == entry.draft.path;
  ref.read(historyProvider.notifier).delete(entry, keepFile: inDraft);
}

// ----- FORMATTING -----

String _summary(HistoryEntry e) {
  final s = e.settings;
  final parts = [s.dither.label, Density.values[s.density.clamp(0, 2)].label];
  if (s.rotation != 0) parts.add('${s.rotation * 90}°');
  if (s.scale == ScaleMode.original) parts.add('Original');
  if (e.draft.isPdf) {
    parts.add(s.pages == PageSelection.all ? '${e.draft.pageCount} pages' : 'p. ${s.pageSpec.trim()}');
  }
  if (s.copies > 1) parts.add('×${s.copies}');
  return parts.join(' · ');
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _day(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${_months[d.month - 1]} ${d.day}${d.year == now.year ? '' : ', ${d.year}'}';
}

String _time(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

// ----- MOBILE -----

class _MobileList extends ConsumerWidget {
  const _MobileList({required this.entries});

  final List<HistoryEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <Widget>[];
    String? lastDay;
    for (final (i, entry) in entries.indexed) {
      final day = _day(entry.printedAt);
      if (day != lastDay) {
        items.add(Padding(
          padding: EdgeInsets.fromLTRB(4, lastDay == null ? 0 : 8, 4, 8),
          child: Text(day.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
        ));
        lastDay = day;
      }
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FadeSlideIn(
          delay: FadeSlideIn.stagger(i.clamp(0, 6)),
          child: Dismissible(
            key: ValueKey(entry.id),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => _delete(ref, entry),
            background: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Text('Delete', style: TextStyle(color: context.glass.accent, fontWeight: FontWeight.w600)),
              ),
            ),
            child: _EntryCard(entry: entry),
          ),
        ),
      ));
    }
    return ListView(padding: const EdgeInsets.only(bottom: Adaptives.mobileNavInset), children: items);
  }
}

class _EntryCard extends ConsumerWidget {
  const _EntryCard({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Hoverable(
      onTap: () => _openAsDraft(ref, entry),
      builder: (hover) => GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _Thumb(entry: entry),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.draft.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(_summary(entry), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _ReprintPill(entry: entry, filled: hover),
          ],
        ),
      ),
    );
  }
}

// ----- DESKTOP -----

class _DesktopTable extends StatelessWidget {
  const _DesktopTable({required this.entries});

  final List<HistoryEntry> entries;

  static const _columns = [52.0, 0.0, 0.0, 150.0, 120.0, 132.0];

  @override
  Widget build(BuildContext context) {
    final label = Theme.of(context).textTheme.labelSmall;
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        children: [
          _TableRow(
            cells: [
              const SizedBox.shrink(),
              Text('FILE', style: label),
              Text('SETTINGS', style: label),
              Text('PRINTER', style: label),
              Text('PRINTED', style: label),
              const SizedBox.shrink(),
            ],
          ),
          Expanded(
            child: ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, i) => FadeSlideIn(
                key: ValueKey(entries[i].id),
                delay: FadeSlideIn.stagger(i.clamp(0, 6)) ~/ 2,
                child: _DesktopEntry(entry: entries[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.cells});

  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          for (final (i, cell) in cells.indexed)
            if (_DesktopTable._columns[i] == 0)
              Expanded(child: Padding(padding: const EdgeInsets.only(right: 16), child: cell))
            else
              SizedBox(
                width: _DesktopTable._columns[i],
                child: Align(alignment: i == cells.length - 1 ? Alignment.centerRight : Alignment.centerLeft, child: cell),
              ),
        ],
      ),
    );
  }
}

class _DesktopEntry extends ConsumerWidget {
  const _DesktopEntry({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.glass;
    final small = Theme.of(context).textTheme.bodySmall;

    return _Hoverable(
      onTap: () => _openAsDraft(ref, entry),
      builder: (hover) => AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(color: hover ? colors.line : Colors.transparent, borderRadius: BorderRadius.circular(12)),
        child: _TableRow(
          cells: [
            _Thumb(entry: entry),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.draft.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${entry.draft.pageCount} page${entry.draft.pageCount == 1 ? '' : 's'}', style: small),
              ],
            ),
            Text(_summary(entry), style: small, maxLines: 2, overflow: TextOverflow.ellipsis),
            Text(entry.deviceName, style: small, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${_day(entry.printedAt)} ${_time(entry.printedAt)}', style: small),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedOpacity(
                  opacity: hover ? 1 : 0,
                  duration: const Duration(milliseconds: 400),
                  child: IconButton(
                    tooltip: 'Delete',
                    iconSize: 16,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                    padding: EdgeInsets.zero,
                    color: colors.muted,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(ref, entry),
                  ),
                ),
                _ReprintPill(entry: entry, filled: hover),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.glass;
    return GlassPanel(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          icon: Icon(Icons.search, size: 18, color: colors.muted),
          hintText: 'Search printed files',
          hintStyle: TextStyle(color: colors.muted),
        ),
      ),
    );
  }
}

// ----- SHARED -----

class _Thumb extends StatelessWidget {
  const _Thumb({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final path = entry.thumbnailPath;
    return Container(
      width: 34,
      height: 42,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.glass.line),
      ),
      child: path == null
          ? null
          : Image.file(File(path), fit: BoxFit.cover, alignment: Alignment.topCenter, filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => const SizedBox.shrink()),
    );
  }
}

class _ReprintPill extends ConsumerWidget {
  const _ReprintPill({required this.entry, required this.filled});

  final HistoryEntry entry;
  final bool filled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.glass;
    final enabled = ref.watch(deviceProvider).valueOrNull != null && !ref.watch(printJobProvider).isRunning;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? () => _reprint(ref, entry) : null,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : .4,
          duration: Motion.fast,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: filled && enabled ? colors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.accent),
            ),
            child: Text(
              'Print',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: filled && enabled ? colors.onAccent : colors.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hoverable extends StatefulWidget {
  const _Hoverable({required this.builder, required this.onTap});

  final Widget Function(bool hover) builder;
  final VoidCallback onTap;

  @override
  State<_Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<_Hoverable> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedSlide(
          offset: Offset(0, _hover ? -.015 : 0),
          duration: const Duration(milliseconds: 500),
          curve: Motion.springy,
          child: widget.builder(_hover),
        ),
      ),
    );
  }
}
