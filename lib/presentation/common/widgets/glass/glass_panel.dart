import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:peripage_app/config/constants.dart';
import 'package:peripage_app/config/theme.dart';

/// Frosted, slightly translucent surface with a hairline edge.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = Styling.cardPadding,
    this.radius = Styling.radius,
    this.strong = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Uses the more opaque glass (selected states, pills).
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final colors = context.glass;
    final shape = BorderRadius.circular(radius);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: Styling.glassBlur, sigmaY: Styling.glassBlur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: strong ? colors.glassStrong : colors.glass,
              borderRadius: shape,
              border: Border.all(color: colors.line),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: const Alignment(0, -.6),
                colors: [colors.glassEdge.withValues(alpha: .35), Colors.transparent],
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
