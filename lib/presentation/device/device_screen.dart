import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peripage_app/config/adaptives.dart';
import 'package:peripage_app/config/constants.dart';
import 'package:peripage_app/config/routes.dart';
import 'package:peripage_app/config/theme.dart';
import 'package:peripage_app/core/device/domain/device_entity.dart';
import 'package:peripage_app/core/device/domain/device_settings.dart';
import 'package:peripage_app/core/device/domain/printer_status.dart';
import 'package:peripage_app/core/device/state/device_provider.dart';
import 'package:peripage_app/core/device/state/printer_status_provider.dart';
import 'package:peripage_app/presentation/common/widgets/current_print_card.dart';
import 'package:peripage_app/presentation/common/widgets/fade_slide_in.dart';
import 'package:peripage_app/presentation/common/widgets/glass/accent_button.dart';
import 'package:peripage_app/presentation/common/widgets/glass/glass_panel.dart';
import 'package:peripage_app/presentation/common/widgets/glass/glass_segmented.dart';
import 'package:peripage_app/presentation/common/widgets/glass/status_pill.dart';
import 'package:peripage_app/presentation/common/widgets/printer_list.dart';
import 'package:peripage_app/presentation/common/widgets/screen_header.dart';
import 'package:peripage_app/presentation/common/widgets/setting_row.dart';

class DeviceScreen extends ConsumerWidget {
  const DeviceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(printerStatusProvider).status;
    final header = ScreenHeader(title: 'Device', trailing: StatusPill(status: status));

    if (!Adaptives.isDesktop(context)) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(Styling.pagePadding, 20, Styling.pagePadding, Adaptives.mobileNavInset),
        children: _stagger(const [
          CurrentPrintCard(),
          _PaperCard(),
          _PrinterInfoCard(),
          _DefaultsCard(),
          _MobileActions(),
        ], header),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(
          child: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: _stagger(const [CurrentPrintCard(), _PaperCard(), _PrinterInfoCard(), _DefaultsCard()]),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _stagger(const [_DesktopPrinters(), _ConnectionCard(), _ConnectButton()], null, 1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static List<Widget> _stagger(List<Widget> cards, [Widget? header, int offset = 0]) => [
    ?header,
    for (final (i, card) in cards.indexed)
      Padding(
        padding: const EdgeInsets.only(bottom: Styling.gap + 4),
        child: FadeSlideIn(delay: FadeSlideIn.stagger(i + offset), child: card),
      ),
  ];
}

/// Whether paper is detected, with an on-demand check and a feed button.
class _PaperCard extends ConsumerStatefulWidget {
  const _PaperCard();

  @override
  ConsumerState<_PaperCard> createState() => _PaperCardState();
}

class _PaperCardState extends ConsumerState<_PaperCard> {
  bool _checking = false;
  bool _feeding = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.glass;
    final view = ref.watch(printerStatusProvider);
    final connected = ref.watch(deviceProvider).valueOrNull != null;
    final settings = ref.watch(deviceSettingsProvider).valueOrNull;
    final paper = settings?.paperType ?? PaperType.roll;
    final printing = view.progress != null;

    final (text, ok) = switch (view.status) {
      _ when !connected => ('Printer not connected', false),
      PrinterStatus.noPaper => (paper == PaperType.sheet ? 'No sheet detected — insert one' : 'No paper detected', false),
      PrinterStatus.printing || PrinterStatus.waitingForPaper => ('In use', true),
      _ => ('Paper loaded', true),
    };

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel('Paper · ${paper.label}'),
          Row(
            children: [
              AnimatedContainer(
                duration: Motion.fast,
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: !connected ? colors.muted : (ok ? AppColors.online : colors.accent),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedSwitcher(duration: Motion.fast, child: Text(text, key: ValueKey(text))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SmallAction(
                  label: 'Check paper',
                  busy: _checking,
                  onTap: connected && !printing ? _check : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SmallAction(
                  label: paper.advancesToNextPage ? 'Next ${paper == PaperType.labels ? 'label' : 'sheet'}' : 'Feed paper',
                  busy: _feeding,
                  onTap: connected && !printing ? _feed : null,
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: Motion.medium,
            curve: Curves.easeInOutCubic,
            child: paper != PaperType.sheet
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SettingRow(
                      label: 'Multi-page prints',
                      child: GlassSegmented<bool>(
                        options: const [true, false],
                        selected: settings?.autoContinueSheets ?? true,
                        labelOf: (auto) => auto ? 'Continue automatically' : 'Ask me',
                        onChanged: (auto) {
                          final current = settings;
                          if (current != null) {
                            ref.read(deviceSettingsProvider.notifier).change(current.copyWith(autoContinueSheets: auto));
                          }
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      await ref.read(polledStatusProvider.notifier).refresh();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _feed() async {
    setState(() => _feeding = true);
    try {
      await ref.read(deviceProvider.notifier).feedPaper();
      await Future<void>.delayed(const Duration(milliseconds: 800)); // let the motor finish before re-checking
      await ref.read(polledStatusProvider.notifier).refresh();
    } finally {
      if (mounted) setState(() => _feeding = false);
    }
  }
}

/// Compact outlined button with an optional spinner.
class _SmallAction extends StatelessWidget {
  const _SmallAction({required this.label, required this.busy, required this.onTap});

  final String label;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.glass;
    final enabled = onTap != null && !busy;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: AnimatedOpacity(
          duration: Motion.fast,
          opacity: onTap == null ? .45 : 1,
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: colors.line,
              borderRadius: BorderRadius.circular(Styling.radiusSmall),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy) ...[
                  SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: colors.ink)),
                  const SizedBox(width: 8),
                ],
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrinterInfoCard extends ConsumerWidget {
  const _PrinterInfoCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceProvider).valueOrNull;
    final saved = ref.watch(savedDeviceProvider).valueOrNull;
    final battery = ref.watch(printerStatusProvider).battery;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('Printer'),
          _InfoRow('Name', device?.name ?? saved?.name ?? '—'),
          _InfoRow('Battery', battery == null ? '—' : '$battery%'),
          _InfoRow('Firmware', device?.firmware ?? '—'),
          _InfoRow('Print width', device == null ? '—' : '${device.widthDots} dots · ${device.dpi} dpi'),
          if (device?.compressedRasterOnly ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'This model normally receives compressed image data. Printing uses the uncompressed format, '
                'which may not be supported by its firmware.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SettingRow(label: label, child: Text(value));
  }
}

class _DefaultsCard extends ConsumerWidget {
  const _DefaultsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(deviceSettingsProvider).valueOrNull ?? const DeviceSettings();
    final notifier = ref.read(deviceSettingsProvider.notifier);
    final width = ref.watch(deviceProvider).valueOrNull?.widthDots;
    // Without a connection, keep showing the options that belong to the chosen paper.
    final a4Paper = settings.paperType == PaperType.sheet || settings.paperType == PaperType.folded;
    final paperChoices = PaperType.choicesFor(width ?? (a4Paper ? 1664 : 384));

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('Defaults'),
          SettingRow(
            label: 'Density',
            child: GlassSegmented<Density>(
              options: Density.values,
              selected: settings.density,
              labelOf: (d) => d.label,
              onChanged: (d) => notifier.change(settings.copyWith(density: d)),
            ),
          ),
          SettingRow(
            label: 'Paper',
            child: GlassSegmented<PaperType>(
              options: paperChoices,
              selected: settings.paperType,
              labelOf: (p) => p.label,
              onChanged: (p) => notifier.change(settings.copyWith(paperType: p)),
            ),
          ),
          AnimatedSwitcher(
            duration: Motion.fast,
            child: Align(
              key: ValueKey(settings.paperType),
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  paperChoices.contains(settings.paperType)
                      ? settings.paperType.description
                      : 'Pick the paper loaded in this printer.',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
          SettingRow(
            label: 'Auto-off',
            child: GlassSegmented<int>(
              options: DeviceSettings.autoOffChoices,
              selected: settings.autoOffMinutes,
              labelOf: (m) => m == 0 ? 'Off' : '${m}m',
              onChanged: (m) => notifier.change(settings.copyWith(autoOffMinutes: m)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionCard extends ConsumerWidget {
  const _ConnectionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(deviceSettingsProvider).valueOrNull ?? const DeviceSettings();
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('Connection'),
          SettingRow(
            label: 'Reconnect on start',
            child: GlassSegmented<bool>(
              options: const [true, false],
              selected: settings.reconnectOnStart,
              labelOf: (on) => on ? 'On' : 'Off',
              onChanged: (on) => ref.read(deviceSettingsProvider.notifier).change(settings.copyWith(reconnectOnStart: on)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Desktop: printers listed inline; tapping one connects to it directly.
class _DesktopPrinters extends ConsumerWidget {
  const _DesktopPrinters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectedId = ref.watch(deviceProvider).valueOrNull?.id;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PrinterListHeader(),
          PrinterList(selectedId: connectedId, onSelect: (d) => ref.read(deviceProvider.notifier).connect(d)),
          _ConnectError(),
        ],
      ),
    );
  }
}

class _ConnectError extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(deviceProvider).error;
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(error.toString(), style: TextStyle(color: context.glass.accent, fontSize: 13)),
    );
  }
}

/// Connect to the saved printer when disconnected, otherwise disconnect.
class _ConnectButton extends ConsumerWidget {
  const _ConnectButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceProvider);
    final saved = ref.watch(savedDeviceProvider).valueOrNull;
    final notifier = ref.read(deviceProvider.notifier);

    if (device.isLoading) return const AccentButton(label: 'Connecting…', onPressed: null, ghost: true, loading: true);
    if (device.valueOrNull != null) return AccentButton(label: 'Disconnect', ghost: true, onPressed: notifier.disconnect);
    return AccentButton(
      label: saved == null ? 'Connect' : 'Connect to ${saved.name}',
      onPressed: saved == null ? null : () => notifier.connect(saved),
    );
  }
}

class _MobileActions extends ConsumerWidget {
  const _MobileActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DeviceEntity? device = ref.watch(deviceProvider).valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (device == null) const _ConnectButton(),
        _ConnectError(),
        Center(child: TextLink('Change printer', onTap: () => Navigator.of(context).pushNamed(Routes.setup))),
      ],
    );
  }
}
