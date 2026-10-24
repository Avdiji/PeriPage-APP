import 'package:flutter/material.dart';
import 'package:peripage_app/config/constants.dart';
import 'package:peripage_app/config/theme.dart';
import 'package:peripage_app/core/device/domain/printer_status.dart';
import 'package:peripage_app/presentation/common/widgets/glass/glass_panel.dart';

/// Small glass pill: status dot + label.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final PrinterStatus status;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 999,
      padding: const EdgeInsets.fromLTRB(11, 6, 12, 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusDot(status: status),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: Motion.fast,
            child: Text(status.label, key: ValueKey(status), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

/// Status colour; pulses softly while connecting or printing.
class StatusDot extends StatefulWidget {
  const StatusDot({super.key, required this.status});

  final PrinterStatus status;

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ping = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));

  bool get _live => const {
    PrinterStatus.printing,
    PrinterStatus.connecting,
    PrinterStatus.waitingForPaper,
  }.contains(widget.status);

  @override
  void initState() {
    super.initState();
    if (_live) _ping.repeat();
  }

  @override
  void didUpdateWidget(StatusDot old) {
    super.didUpdateWidget(old);
    if (_live && !_ping.isAnimating) _ping.repeat();
    if (!_live) _ping.stop();
  }

  @override
  void dispose() {
    _ping.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.glass;
    final color = switch (widget.status) {
      PrinterStatus.idle => AppColors.online,
      PrinterStatus.disconnected => colors.muted,
      _ => colors.accent,
    };

    return AnimatedBuilder(
      animation: _ping,
      builder: (context, _) {
        final t = Curves.easeOut.transform((_ping.value / .7).clamp(0, 1));
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: _live ? [BoxShadow(color: color.withValues(alpha: .4 * (1 - t)), spreadRadius: 7 * t)] : null,
          ),
        );
      },
    );
  }
}
