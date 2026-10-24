import 'package:flutter/material.dart';

abstract final class Adaptives {
  /// From this width on the app uses the desktop layout (sidebar, two-column views).
  static const desktopBreak = 900.0;

  /// Room the floating mobile tab bar needs at the bottom of each view.
  static const mobileNavInset = 92.0;

  static bool isDesktop(BuildContext context) => MediaQuery.sizeOf(context).width >= desktopBreak;
}
