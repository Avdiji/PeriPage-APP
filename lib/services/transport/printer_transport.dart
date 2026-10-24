import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peripage_app/services/transport/models/discovered_device_in.dart';

/// Byte pipe to a printer. Implemented per platform and injected in main.dart.
abstract interface class PrinterTransport {
  Future<List<DiscoveredDeviceIn>> discover();

  Future<void> connect(DiscoveredDeviceIn device);

  Future<void> disconnect();

  bool get isConnected;

  /// Writes [data] and completes once it was handed to the OS.
  Future<void> write(Uint8List data);

  /// Bytes received from the printer.
  Stream<Uint8List> get incoming;
}

final class PrinterTransportException implements Exception {
  final String message;
  const PrinterTransportException(this.message);

  @override
  String toString() => message;
}

/// Must be overridden in main.dart.
final printerTransportProvider = Provider<PrinterTransport>(
  (Ref ref) => throw UnimplementedError('Must be overridden in main.dart'),
);
