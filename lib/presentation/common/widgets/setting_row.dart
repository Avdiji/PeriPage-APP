import 'package:flutter/material.dart';
import 'package:peripage_app/config/theme.dart';

/// "Label …… control" row used inside settings cards.
class SettingRow extends StatelessWidget {
  const SettingRow({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 2,
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.glass.muted)),
          ),
          const SizedBox(width: 16),
          // Narrow screens shrink the control rather than overflow.
          Flexible(
            flex: 5,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(fit: BoxFit.scaleDown, child: child),
            ),
          ),
        ],
      ),
    );
  }
}

/// Uppercase caption above a card's content.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall)),
          ?trailing,
        ],
      ),
    );
  }
}

/// Muted text that turns ink-coloured on hover.
class TextLink extends StatefulWidget {
  const TextLink(this.text, {super.key, required this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  State<TextLink> createState() => _TextLinkState();
}

class _TextLinkState extends State<TextLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.glass;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(fontSize: 13, color: _hover ? colors.ink : colors.muted),
            child: Text(widget.text),
          ),
        ),
      ),
    );
  }
}
