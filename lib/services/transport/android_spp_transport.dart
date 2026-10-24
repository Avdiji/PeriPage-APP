import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:peripage_app/services/protocol/printer_models.dart';
import 'package:peripage_app/services/transport/models/discovered_device_in.dart';
import 'package:peripage_app/services/transport/printer_transport.dart';
import 'package:permission_handler/permission_handler.dart';

/// Bluetooth Classic RFCOMM (SPP), the transport the official app uses.
final class AndroidSppTransport implements PrinterTransport {
  static const _sppUuid = '00001101-0000-1000-8000-00805f9b34fb';

  final FlutterBlueClassic _bluetooth = FlutterBlueClassic();
  final StreamController<Uint8List> _incoming = StreamController<Uint8List>.broadcast();
  BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _inputSub;

  static const _scanDuration = Duration(seconds: 8);

  /// Paired devices plus everything an 8 s inquiry finds, PeriPage printers only if there are any.
  @override
  Future<List<DiscoveredDeviceIn>> discover() async {
    await _ensurePermissions();
    if (!await _bluetooth.isEnabled) {
      throw const PrinterTransportException('Bluetooth is turned off.');
    }

    final found = <String, DiscoveredDeviceIn>{
      for (final d in await _bluetooth.bondedDevices ?? const <BluetoothDevice>[])
        d.address: DiscoveredDeviceIn(id: d.address, name: d.name ?? d.address, detail: 'Paired'),
    };
    final sub = _bluetooth.scanResults.listen((d) {
      final name = d.name;
      if (name == null || name.isEmpty) return;
      found.putIfAbsent(d.address, () => DiscoveredDeviceIn(id: d.address, name: name, detail: 'Not paired yet · pairs on connect'));
    });
    _bluetooth.startScan();
    try {
      await Future<void>.delayed(_scanDuration);
    } finally {
      _bluetooth.stopScan();
      await sub.cancel();
    }

    final devices = found.values.toList();
    final printers = devices.where((d) => PrinterModel.isPeriPage(d.name)).toList();
    return printers.isNotEmpty ? printers : devices;
  }

  @override
  Future<void> connect(DiscoveredDeviceIn device) async {
    await disconnect();
    await _ensurePermissions();
    _bluetooth.stopScan(); // an ongoing inquiry slows down RFCOMM connects
    final connection = await _bluetooth.connect(device.id, uuid: _sppUuid);
    if (connection == null || !connection.isConnected) {
      throw PrinterTransportException("Couldn't reach ${device.name}. Is it switched on and in range?");
    }
    _connection = connection;
    _inputSub = connection.input?.listen(_incoming.add, onDone: () => _connection = null);
  }

  @override
  Future<void> disconnect() async {
    await _inputSub?.cancel();
    _inputSub = null;
    await _connection?.close();
    _connection = null;
  }

  @override
  bool get isConnected => _connection?.isConnected ?? false;

  @override
  Future<void> write(Uint8List data) async {
    final connection = _connection;
    if (connection == null || !connection.isConnected) {
      throw const PrinterTransportException('Printer is not connected.');
    }
    connection.output.add(data);
    await connection.output.allSent;
  }

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  Future<void> _ensurePermissions() async {
    final statuses = await [Permission.bluetoothConnect, Permission.bluetoothScan].request();
    if (statuses.values.any((s) => s.isPermanentlyDenied || s.isRestricted)) {
      throw const PrinterTransportException('Bluetooth permission was denied.');
    }
    // Android 11 and older need location for scanning; newer versions don't declare it, so ignore the result.
    await Permission.locationWhenInUse.request();
  }
}
