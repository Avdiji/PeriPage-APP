import 'package:flutter/material.dart';
import 'package:peripage_app/presentation/device/setup_screen.dart';
import 'package:peripage_app/presentation/shell/start_gate.dart';

final class Routes {
  const Routes._();

  static const home = '/';
  static const setup = '/setup';

  static Map<String, WidgetBuilder> get routes => {
    home: (context) => const StartGate(),
    setup: (context) => const SetupScreen(),
  };
}
