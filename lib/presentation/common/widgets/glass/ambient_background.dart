import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:peripage_app/config/theme.dart';

/// Soft, slowly drifting colour blobs that give the glass panels something to refract.
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 38))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.glass;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) _drift.stop();

    return ColoredBox(
      color: colors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70, tileMode: TileMode.decal),
              child: AnimatedBuilder(
                animation: _drift,
                builder: (context, _) {
                  final t = Curves.easeInOut.transform(_drift.value);
                  return CustomPaint(painter: _BlobPainter(colors.blobs, t), size: Size.infinite);
                },
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter(this.colors, this.t);

  final List<Color> colors;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    void blob(Color color, Offset base, Offset travel, double radius, double opacity) {
      final paint = Paint()..color = color.withValues(alpha: opacity);
      canvas.drawCircle(base + travel * t, radius * (1 + .08 * t), paint);
    }

    blob(colors[0], Offset(size.width * .85, size.height * .05), Offset(-s * .07, s * .09), s * .38, .35);
    blob(colors[1], Offset(size.width * .1, size.height * .85), Offset(s * .06, -s * .08), s * .44, .35);
    blob(colors[2], Offset(size.width * 1.02, size.height * .5), Offset(-s * .08, s * .05), s * .3, .3);
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.t != t || old.colors != colors;
}
