import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peripage_app/config/constants.dart';
import 'package:peripage_app/config/theme.dart';
import 'package:peripage_app/core/device/domain/device_entity.dart';
import 'package:peripage_app/core/device/state/device_provider.dart';
import 'package:peripage_app/presentation/common/widgets/glass/progress_line.dart';
import 'package:peripage_app/presentation/common/widgets/setting_row.dart';

/// Printers in range. Tapping a row selects it; [selectedId] shows a tick, a connect in progress a spinner.
/// Results of the previous scan stay visible while a new scan runs.
class PrinterList extends ConsumerWidget {
  const PrinterList({super.key, required this.selectedId, required this.onSelect});

  final String? selectedId;
  final ValueChanged<DeviceCandidate> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.glass;
    final discovery = ref.watch(discoveryProvider);
    final connectingId = ref.watch(connectingIdProvider);
    final devices = discovery.valueOrNull ?? const <DeviceCandidate>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: Motion.medium,
          curve: Curves.easeInOutCubic,
          child: discovery.isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Message('Searching for printers nearby… this takes a few seconds.'),
                      SizedBox(height: 10),
                      IndeterminateLine(),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        if (!discovery.isLoading && discovery.hasError) _Message(discovery.error.toString()),
        if (!discovery.isLoading && !discovery.hasError && devices.isEmpty)
          const _Message('No printers found. Make sure the printer is switched on, close to this device and not '
              'connected to your phone, then scan again.'),
        for (final (i, d) in devices.indexed)
          _PrinterRow(
            device: d,
            selected: d.id == selectedId,
            connecting: d.id == connectingId,
            divider: i < devices.length - 1,
            onTap: connectingId == null ? () => onSelect(d) : null,
            lineColor: colors.line,
          ),
      ],
    );
  }
}

class _PrinterRow extends StatelessWidget {
  const _PrinterRow({
    required this.device,
    required this.selected,
    required this.connecting,
    required this.divider,
    required this.onTap,
    required this.lineColor,
  });

  final DeviceCandidate device;
  final bool selected;
  final bool connecting;
  final bool divider;
  final VoidCallback? onTap;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.glass;
    return MouseRegion(
      cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: divider ? Border(bottom: BorderSide(color: lineColor)) : null),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name),
                    Text(
                      connecting ? 'Connecting…' : (device.detail ?? ''),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 22,
                height: 22,
                child: AnimatedSwitcher(
                  duration: Motion.fast,
                  child: connecting
                      ? Padding(
                          key: const ValueKey('spinner'),
                          padding: const EdgeInsets.all(3),
                          child: CircularProgressIndicator(strokeWidth: 1.8, color: colors.accent),
                        )
                      : AnimatedScale(
                          key: const ValueKey('tick'),
                          scale: selected ? 1 : 0,
                          duration: const Duration(milliseconds: 700),
                          curve: const Cubic(.3, 1.3, .5, 1),
                          child: Container(
                            decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
                            child: Icon(Icons.check, size: 13, color: colors.onAccent),
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

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text, style: TextStyle(color: context.glass.muted, fontSize: 13)),
    );
  }
}

/// Section header with a rescan action that turns into "Scanning…" while a scan runs.
class PrinterListHeader extends ConsumerWidget {
  const PrinterListHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanning = ref.watch(discoveryProvider).isLoading;
    final connecting = ref.watch(connectingIdProvider) != null;
    return SectionLabel(
      'Printers',
      trailing: AnimatedSwitcher(
        duration: Motion.fast,
        child: scanning
            ? Row(
                key: const ValueKey('scanning'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: context.glass.muted),
                  ),
                  const SizedBox(width: 8),
                  Text('Scanning…', style: TextStyle(fontSize: 13, color: context.glass.muted)),
                ],
              )
            : TextLink(
                'Scan again',
                key: const ValueKey('rescan'),
                onTap: connecting ? null : () => ref.invalidate(discoveryProvider),
              ),
      ),
    );
  }
}
