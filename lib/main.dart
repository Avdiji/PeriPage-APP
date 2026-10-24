import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peripage_app/app.dart';
import 'package:peripage_app/services/transport/android_spp_transport.dart';
import 'package:peripage_app/services/transport/printer_transport.dart';
import 'package:peripage_app/services/transport/windows_bluetooth_transport.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final PrinterTransport transport = Platform.isWindows ? WindowsBluetoothTransport() : AndroidSppTransport();

  runApp(
    ProviderScope(
      overrides: [printerTransportProvider.overrideWithValue(transport)],
      child: const PeriPageApp(),
    ),
  );
}
