import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peripage_app/core/device/state/device_provider.dart';
import 'package:peripage_app/presentation/common/widgets/glass/ambient_background.dart';
import 'package:peripage_app/presentation/device/setup_screen.dart';
import 'package:peripage_app/presentation/shell/app_shell.dart';

/// Shows setup on first run, the app shell afterwards.
class StartGate extends ConsumerWidget {
  const StartGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedDeviceProvider);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      child: saved.when(
        loading: () => const Scaffold(body: AmbientBackground(child: SizedBox.expand())),
        error: (_, _) => const SetupScreen(firstRun: true),
        data: (device) => device == null ? const SetupScreen(firstRun: true) : const AppShell(),
      ),
    );
  }
}
