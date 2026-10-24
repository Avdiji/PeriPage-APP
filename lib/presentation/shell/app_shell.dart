import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peripage_app/config/adaptives.dart';
import 'package:peripage_app/config/constants.dart';
import 'package:peripage_app/config/theme.dart';
import 'package:peripage_app/core/device/state/device_provider.dart';
import 'package:peripage_app/core/printing/state/draft_provider.dart';
import 'package:peripage_app/core/printing/state/print_job_provider.dart';
import 'package:peripage_app/presentation/common/widgets/current_print_card.dart';
import 'package:peripage_app/presentation/common/widgets/glass/ambient_background.dart';
import 'package:peripage_app/presentation/common/widgets/glass/glass_panel.dart';
import 'package:peripage_app/presentation/common/widgets/next_sheet_prompt.dart';
import 'package:peripage_app/presentation/device/device_screen.dart';
import 'package:peripage_app/presentation/draft/draft_screen.dart';
import 'package:peripage_app/presentation/history/history_screen.dart';

enum ShellTab {
  draft('Draft'),
  history('History'),
  device('Device');

  final String label;
  const ShellTab(this.label);
}

final shellTabProvider = StateProvider<ShellTab>((Ref ref) => ShellTab.draft);

/// Navigation frame: glass sidebar on desktop, floating glass tab bar on phones.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(shellTabProvider);
    final desktop = Adaptives.isDesktop(context);

    ref.listen(printJobProvider, (previous, next) {
      final messenger = ScaffoldMessenger.of(context);
      final finished = next.finished;
      if (finished != null && previous?.finished == null) {
        messenger.showSnackBar(SnackBar(
          duration: Duration(seconds: finished.confirmed ? 4 : 8),
          content: Text(
            finished.confirmed
                ? 'Printed ${finished.fileName}.'
                : 'Sent ${finished.fileName}, but the printer never confirmed that it printed. '
                      'Check the printer — it may not accept this data format.',
          ),
        ));
      } else if (next.cancelled && !(previous?.cancelled ?? false)) {
        messenger.showSnackBar(const SnackBar(content: Text('Print cancelled.')));
      } else if (next.error != null && previous?.error == null) {
        messenger.showSnackBar(SnackBar(content: Text('Print failed: ${next.error}')));
      }
    });

    final view = AnimatedSwitcher(
      duration: Motion.medium,
      switchInCurve: Motion.curve,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, .012), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey(tab),
        child: switch (tab) {
          ShellTab.draft => const DraftScreen(),
          ShellTab.history => const HistoryScreen(),
          ShellTab.device => const DeviceScreen(),
        },
      ),
    );

    void select(ShellTab t) => ref.read(shellTabProvider.notifier).state = t;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () => select(ShellTab.draft),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () => select(ShellTab.history),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () => select(ShellTab.device),
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): () {
          select(ShellTab.draft);
          ref.read(draftProvider.notifier).pick();
        },
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () {
          if (ref.read(deviceProvider).valueOrNull != null && !ref.read(printJobProvider).isRunning) printDraft(ref);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: AmbientBackground(
            child: Stack(
              children: [
                Positioned.fill(
                  child: desktop
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(width: 232, child: _Sidebar(selected: tab, onSelect: select)),
                              const SizedBox(width: 20),
                              Expanded(child: view),
                            ],
                          ),
                        )
                      : SafeArea(
                          child: Stack(
                            children: [
                              Positioned.fill(child: view),
                              Align(alignment: Alignment.bottomCenter, child: _FloatingNav(selected: tab, onSelect: select)),
                            ],
                          ),
                        ),
                ),
                const Positioned.fill(child: NextSheetPrompt()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.selected, required this.onSelect});

  final ShellTab selected;
  final ValueChanged<ShellTab> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.glass;
    final deviceName = ref.watch(deviceProvider).valueOrNull?.name ?? ref.watch(savedDeviceProvider).valueOrNull?.name;

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 0, 10, 22),
            child: Text('PeriPage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -.3)),
          ),
          for (final (i, tab) in ShellTab.values.indexed)
            _SidebarLink(
              label: tab.label,
              shortcut: 'Ctrl ${i + 1}',
              selected: tab == selected,
              onTap: () => onSelect(tab),
              colors: colors,
            ),
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => onSelect(ShellTab.device),
              child: Tooltip(message: 'Open Device', waitDuration: const Duration(milliseconds: 600), child: MiniStatus(deviceName: deviceName)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarLink extends StatelessWidget {
  const _SidebarLink({
    required this.label,
    required this.shortcut,
    required this.selected,
    required this.onTap,
    required this.colors,
  });

  final String label;
  final String shortcut;
  final bool selected;
  final VoidCallback onTap;
  final GlassColors colors;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? colors.glassStrong : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 3, offset: const Offset(0, 1))] : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: Motion.fast,
                  style: TextStyle(
                    fontSize: 14,
                    color: selected ? colors.ink : colors.muted,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  child: Text(label),
                ),
              ),
              Text(shortcut, style: TextStyle(fontSize: 11, color: colors.muted.withValues(alpha: .6))),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingNav extends StatelessWidget {
  const _FloatingNav({required this.selected, required this.onSelect});

  final ShellTab selected;
  final ValueChanged<ShellTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.glass;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GlassPanel(
        radius: 999,
        padding: const EdgeInsets.all(5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final tab in ShellTab.values)
              GestureDetector(
                onTap: () => onSelect(tab),
                child: AnimatedContainer(
                  duration: Motion.fast,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: tab == selected ? colors.glassStrong : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: tab == selected ? colors.ink : colors.muted,
                      fontWeight: tab == selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
