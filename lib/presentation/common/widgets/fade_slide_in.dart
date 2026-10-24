import 'package:flutter/material.dart';
import 'package:peripage_app/config/constants.dart';

/// Entrance animation: fades in and rises a few pixels after [delay].
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  /// Convenience for staggered lists.
  static Duration stagger(int index) => Duration(milliseconds: 150 * index);

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: Motion.slow);
  late final Animation<double> _curve = CurvedAnimation(parent: _controller, curve: Motion.curve);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(offset: Offset(0, 6 * (1 - _curve.value)), child: child),
      ),
    );
  }
}
