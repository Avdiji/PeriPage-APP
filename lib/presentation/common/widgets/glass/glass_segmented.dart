import 'package:flutter/material.dart';
import 'package:peripage_app/config/constants.dart';
import 'package:peripage_app/config/theme.dart';

/// Segmented control whose glass thumb slides to the selected option.
class GlassSegmented<T> extends StatelessWidget {
  const GlassSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.labelOf,
    this.enabled = true,
  });

  final List<T> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.glass;
    final index = options.indexOf(selected).clamp(0, options.length - 1);
    final x = options.length == 1 ? 0.0 : -1 + 2 * index / (options.length - 1);

    return Opacity(
      opacity: enabled ? 1 : .5,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: colors.line, borderRadius: BorderRadius.circular(Styling.radiusSmall)),
        child: IntrinsicWidth(
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedAlign(
                  alignment: Alignment(x, 0),
                  duration: const Duration(milliseconds: 550),
                  curve: Motion.springy,
                  child: FractionallySizedBox(
                    widthFactor: 1 / options.length,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.glassStrong,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 3, offset: const Offset(0, 1)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final option in options)
                    Expanded(
                      child: _Segment(
                        label: labelOf(option),
                        selected: option == selected,
                        onTap: enabled ? () => onChanged(option) : null,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.glass;
    return MouseRegion(
      cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 400),
            style: TextStyle(
              fontSize: 12,
              color: selected ? colors.ink : colors.muted,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
            child: Text(label, textAlign: TextAlign.center, maxLines: 1),
          ),
        ),
      ),
    );
  }
}
