import 'package:flutter/material.dart';
import 'package:peripage_app/config/theme.dart';

/// Thin bar with a segment gliding back and forth, for work of unknown length (scanning, connecting).
class IndeterminateLine extends StatefulWidget {
  const IndeterminateLine({super.key, this.height = 3});

  final double height;

  @override
  State<IndeterminateLine> createState() => _IndeterminateLineState();
}

class _IndeterminateLineState extends State<IndeterminateLine> with SingleTickerProviderStateMixin {
  late final AnimationController _glide = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _glide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.glass;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.height),
      child: SizedBox(
        height: widget.height,
        child: ColoredBox(
          color: colors.line,
          child: AnimatedBuilder(
            animation: _glide,
            builder: (context, _) => Align(
              alignment: Alignment(-1 + 2 * Curves.easeInOutCubic.transform(_glide.value), 0),
              child: FractionallySizedBox(
                widthFactor: .35,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: colors.accent, borderRadius: BorderRadius.circular(widget.height)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin progress bar that eases towards [value] with a slow shimmer while active.
class ProgressLine extends StatefulWidget {
  const ProgressLine({super.key, required this.value, this.height = 5});

  final double value;
  final double height;

  @override
  State<ProgressLine> createState() => _ProgressLineState();
}

class _ProgressLineState extends State<ProgressLine> with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.glass;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.height),
      child: SizedBox(
        height: widget.height,
        child: ColoredBox(
          color: colors.line,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: widget.value.clamp(0, 1)),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOut,
            builder: (context, value, _) => FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value,
              child: AnimatedBuilder(
                animation: _shimmer,
                builder: (context, _) => DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.accent,
                    gradient: LinearGradient(
                      begin: Alignment(-3 + 6 * _shimmer.value, 0),
                      end: Alignment(-1 + 6 * _shimmer.value, 0),
                      colors: [colors.accent, Color.lerp(colors.accent, Colors.white, .35)!, colors.accent],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
