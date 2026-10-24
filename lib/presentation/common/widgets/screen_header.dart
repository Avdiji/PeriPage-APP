import 'package:flutter/material.dart';

/// Large view title with an optional trailing widget (status pill, counter).
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.trailing, this.padding = const EdgeInsets.fromLTRB(4, 14, 4, 18)});

  final String title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineMedium)),
          ?trailing,
        ],
      ),
    );
  }
}
