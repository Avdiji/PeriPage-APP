import 'package:flutter/material.dart';
import 'package:peripage_app/config/theme.dart';

/// Primary action with a faint periodic sheen. [onPressed] null disables it.
class AccentButton extends StatefulWidget {
  const AccentButton({super.key, required this.label, required this.onPressed, this.ghost = false, this.loading = false});

  final String label;
  final VoidCallback? onPressed;

  /// Shows a spinner next to the label and ignores taps.
  final bool loading;

  /// Outlined secondary variant without sheen.
  final bool ghost;

  @override
  State<AccentButton> createState() => _AccentButtonState();
}

class _AccentButtonState extends State<AccentButton> with SingleTickerProviderStateMixin {
  late final AnimationController _sheen = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();
  bool _pressed = false;

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.glass;
    final enabled = widget.onPressed != null && !widget.loading;
    final background = widget.ghost ? Colors.transparent : colors.accent;
    final foreground = widget.ghost ? colors.ink : colors.onAccent;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _pressed ? .985 : 1,
          duration: const Duration(milliseconds: 250),
          child: AnimatedOpacity(
            // A loading button stays fully visible; only truly disabled ones fade.
            opacity: enabled || widget.loading ? 1 : .45,
            duration: const Duration(milliseconds: 400),
            child: Container(
              height: 50,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(16),
                border: widget.ghost ? Border.all(color: colors.line) : null,
                boxShadow: widget.ghost || !enabled
                    ? null
                    : [BoxShadow(color: colors.accent.withValues(alpha: .35), blurRadius: 16, offset: const Offset(0, 6), spreadRadius: -10)],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (!widget.ghost && enabled && !MediaQuery.disableAnimationsOf(context))
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _sheen,
                        builder: (context, _) {
                          // Idle for the first 60 % of the cycle, then sweep once.
                          final t = ((_sheen.value - .6) / .4).clamp(0.0, 1.0);
                          return FractionalTranslation(
                            translation: Offset(-1 + 2 * Curves.easeInOut.transform(t), 0),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.transparent, Colors.white.withValues(alpha: .14), Colors.transparent],
                                  stops: const [.35, .5, .65],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSize(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        child: widget.loading
                            ? Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 1.8, color: foreground),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      Text(widget.label, style: TextStyle(color: foreground, fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
