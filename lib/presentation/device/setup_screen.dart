import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peripage_app/config/constants.dart';
import 'package:peripage_app/config/theme.dart';
import 'package:peripage_app/core/device/domain/device_entity.dart';
import 'package:peripage_app/core/device/domain/printer_status.dart';
import 'package:peripage_app/core/device/state/device_provider.dart';
import 'package:peripage_app/presentation/common/widgets/fade_slide_in.dart';
import 'package:peripage_app/presentation/common/widgets/glass/accent_button.dart';
import 'package:peripage_app/presentation/common/widgets/glass/ambient_background.dart';
import 'package:peripage_app/presentation/common/widgets/glass/glass_panel.dart';
import 'package:peripage_app/presentation/common/widgets/glass/status_pill.dart';
import 'package:peripage_app/presentation/common/widgets/printer_list.dart';
import 'package:peripage_app/presentation/common/widgets/screen_header.dart';
import 'package:peripage_app/presentation/common/widgets/setting_row.dart';

/// First run (no saved printer) or "Change printer": pick a printer and connect.
final class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key, this.firstRun = false});

  final bool firstRun;

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

final class _SetupScreenState extends ConsumerState<SetupScreen> {
  DeviceCandidate? _selected;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final connecting = ref.watch(deviceProvider).isLoading;
    final scanning = ref.watch(discoveryProvider).isLoading;
    final colors = context.glass;

    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Styling.pagePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ScreenHeader(
                      title: 'Set up',
                      padding: const EdgeInsets.fromLTRB(4, 28, 4, 8),
                      trailing: StatusPill(
                        status: connecting || scanning ? PrinterStatus.connecting : PrinterStatus.disconnected,
                      ),
                    ),
                    FadeSlideIn(delay: FadeSlideIn.stagger(1), child: _Radar(active: scanning || connecting)),
                    FadeSlideIn(
                      delay: FadeSlideIn.stagger(2),
                      child: Text(
                        'Turn the printer on. It has to be paired in your system Bluetooth settings first.',
                        style: TextStyle(color: colors.muted),
                      ),
                    ),
                    const SizedBox(height: Styling.gap),
                    Flexible(
                      child: FadeSlideIn(
                        delay: FadeSlideIn.stagger(3),
                        child: GlassPanel(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const PrinterListHeader(),
                                PrinterList(
                                  selectedId: _selected?.id,
                                  onSelect: (d) => setState(() => _selected = d),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!, style: TextStyle(color: colors.accent, fontSize: 13)),
                      ),
                    const Spacer(),
                    FadeSlideIn(
                      delay: FadeSlideIn.stagger(4),
                      child: AccentButton(
                        label: connecting ? 'Connecting…' : 'Connect',
                        loading: connecting,
                        onPressed: _selected == null ? null : _connect,
                      ),
                    ),
                    if (!widget.firstRun) Center(child: TextLink('Cancel', onTap: () => Navigator.of(context).pop())),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _connect() async {
    setState(() => _error = null);
    await ref.read(deviceProvider.notifier).connect(_selected!);
    if (!mounted) return;

    final result = ref.read(deviceProvider);
    if (result.hasError) {
      setState(() => _error = result.error.toString());
      return;
    }
    // On first run StartGate swaps to the shell once the saved device appears.
    if (!widget.firstRun) Navigator.of(context).pop();
  }
}

/// Slow expanding rings around a glass printer icon.
class _Radar extends StatefulWidget {
  const _Radar({required this.active});

  final bool active;

  @override
  State<_Radar> createState() => _RadarState();
}

class _RadarState extends State<_Radar> with SingleTickerProviderStateMixin {
  late final AnimationController _rings = AnimationController(vsync: this, duration: const Duration(milliseconds: 4500))
    ..repeat();

  @override
  void dispose() {
    _rings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.glass;
    return SizedBox(
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.active)
            for (var i = 0; i < 3; i++)
              AnimatedBuilder(
                animation: _rings,
                builder: (context, _) {
                  final t = Curves.easeOut.transform((_rings.value + i / 3) % 1);
                  return Opacity(
                    opacity: .5 * (1 - t),
                    child: Container(
                      width: 56 * (.7 + 1.5 * t),
                      height: 56 * (.7 + 1.5 * t),
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: colors.accent)),
                    ),
                  );
                },
              ),
          GlassPanel(
            radius: 24,
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.print_outlined, color: colors.ink, size: 22),
          ),
        ],
      ),
    );
  }
}
