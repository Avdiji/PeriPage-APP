import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:peripage_app/services/protocol/printer_models.dart';
import 'package:peripage_app/services/transport/models/discovered_device_in.dart';
import 'package:peripage_app/services/transport/printer_transport.dart';
import 'package:win32/win32.dart' hide connect;
import 'package:win32/win32.dart' as ws show connect;

/// Bluetooth Classic on Windows without COM ports: inquiry and pairing via the Win32 Bluetooth API,
/// data via an RFCOMM socket to the printer's serial port service.
///
/// Inquiry, pairing and connecting block for seconds, so they run in short-lived isolates (a socket handle is
/// valid process-wide). Once connected the socket is non-blocking and polled on the main isolate: a
/// long-lived isolate parked in `recv` could never be interrupted, which stalls hot restart and app exit.
final class WindowsBluetoothTransport implements PrinterTransport {
  static const _pollInterval = Duration(milliseconds: 15);
  static const _readSize = 1024;

  final StreamController<Uint8List> _incoming = StreamController<Uint8List>.broadcast();
  final Map<String, bool> _paired = {};
  int? _socket;
  Timer? _poll;
  Pointer<Uint8>? _readBuffer;

  @override
  Future<List<DiscoveredDeviceIn>> discover() async {
    final found = await Isolate.run(_inquiry);
    final devices = <DiscoveredDeviceIn>[];
    final printers = <DiscoveredDeviceIn>[];
    for (final (address, name, paired, deviceClass) in found) {
      final isPrinterClass = _isPrinterClass(deviceClass);
      if (name.isEmpty && !isPrinterClass) continue; // unnamed headsets, phones, …
      final id = _formatAddress(address);
      _paired[id] = paired;
      final device = DiscoveredDeviceIn(
        id: id,
        // Name resolution occasionally fails during inquiry; the model is read from the printer on connect.
        name: name.isEmpty ? 'Printer $id' : name,
        detail: paired ? 'Paired' : 'Not paired yet · pairs on connect',
      );
      devices.add(device);
      if (PrinterModel.isPeriPage(name) || isPrinterClass) printers.add(device);
    }
    return printers.isNotEmpty ? printers : devices;
  }

  @override
  Future<void> connect(DiscoveredDeviceIn device) async {
    await disconnect();
    final address = _parseAddress(device.id);
    final pair = !(_paired[device.id] ?? false);

    final socket = await Isolate.run(() => _open(address, pair));
    if (socket == null) {
      throw PrinterTransportException("Couldn't reach ${device.name}. Is it switched on and in range?");
    }
    _socket = socket;
    _readBuffer = calloc<Uint8>(_readSize);
    _poll = Timer.periodic(_pollInterval, (_) => _drain());
  }

  @override
  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;
    _poll?.cancel();
    _poll = null;
    if (socket != null) closesocket(SOCKET(socket));
    final buffer = _readBuffer;
    _readBuffer = null;
    if (buffer != null) calloc.free(buffer);
  }

  @override
  bool get isConnected => _socket != null;

  @override
  Future<void> write(Uint8List data) async {
    final socket = _socket;
    if (socket == null) throw const PrinterTransportException('Printer is not connected.');

    final buffer = calloc<Uint8>(data.length);
    try {
      buffer.asTypedList(data.length).setAll(0, data);
      var offset = 0;
      var waited = Duration.zero;
      while (offset < data.length) {
        final result = send(SOCKET(socket), PCSTR((buffer + offset).cast()), data.length - offset, const SEND_RECV_FLAGS(0));
        if (result.value > 0) {
          offset += result.value;
          waited = Duration.zero;
        } else if (result.value < 0 && result.error == _wouldBlock && waited < _writeStallLimit) {
          // Send buffer full: the printer is still consuming earlier data.
          await Future<void>.delayed(const Duration(milliseconds: 5));
          waited += const Duration(milliseconds: 5);
        } else {
          await disconnect();
          throw const PrinterTransportException('Connection to the printer was lost.');
        }
      }
    } finally {
      calloc.free(buffer);
    }
  }

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  static const _writeStallLimit = Duration(seconds: 15);

  /// Reads everything that has arrived without blocking.
  void _drain() {
    final socket = _socket;
    final buffer = _readBuffer;
    if (socket == null || buffer == null) return;
    while (true) {
      final result = recv(SOCKET(socket), PSTR(buffer.cast()), _readSize, const SEND_RECV_FLAGS(0));
      if (result.value > 0) {
        _incoming.add(Uint8List.fromList(buffer.asTypedList(result.value)));
        continue;
      }
      if (result.value < 0 && result.error == _wouldBlock) return; // nothing more right now
      // 0 = closed by the printer, other errors = link lost (switched off, out of range).
      disconnect();
      return;
    }
  }

  // ----- ISOLATE ENTRY POINTS -----

  /// Inquiry (~6 s) plus already known devices: (address, name, paired, class of device).
  static List<(int, String, bool, int)> _inquiry() {
    final params = calloc<BLUETOOTH_DEVICE_SEARCH_PARAMS>();
    final info = calloc<BLUETOOTH_DEVICE_INFO>();
    final results = <(int, String, bool, int)>[];
    try {
      params.ref
        ..dwSize = sizeOf<BLUETOOTH_DEVICE_SEARCH_PARAMS>()
        ..fReturnAuthenticated = true
        ..fReturnRemembered = true
        ..fReturnUnknown = true
        ..fReturnConnected = true
        ..fIssueInquiry = true
        ..cTimeoutMultiplier = 5;
      info.ref.dwSize = sizeOf<BLUETOOTH_DEVICE_INFO>();

      final find = BluetoothFindFirstDevice(params, info).value;
      if (!find.isValid) return results; // no radio or nothing found
      do {
        final address = info.ref.Address.Anonymous.ullLong;
        final name = info.ref.szName.isNotEmpty ? info.ref.szName : _lookupName(address);
        results.add((address, name, info.ref.fAuthenticated, info.ref.ulClassofDevice));
        info.ref.dwSize = sizeOf<BLUETOOTH_DEVICE_INFO>();
      } while (BluetoothFindNextDevice(find, info).value);
      find.close();
    } finally {
      calloc
        ..free(params)
        ..free(info);
    }
    return results;
  }

  /// Pairs if needed, then opens an RFCOMM socket to the SPP service. Null if the printer is unreachable.
  static int? _open(int address, bool pair) {
    if (pair) {
      final info = calloc<BLUETOOTH_DEVICE_INFO>();
      info.ref
        ..dwSize = sizeOf<BLUETOOTH_DEVICE_INFO>()
        ..Address.Anonymous.ullLong = address;
      // PeriPage printers use "just works" pairing; if Windows needs a PIN it shows its own prompt.
      BluetoothAuthenticateDeviceEx(null, null, info, null, MITMProtectionNotRequired);
      calloc.free(info);
    }

    _ensureWinsock();
    final socket = socket_(AF_BTH, SOCK_STREAM, _rfcommProtocol);
    if (socket == -1) return null;

    final target = calloc<SOCKADDR_BTH>();
    try {
      target.ref
        ..addressFamily = AF_BTH
        ..btAddr = address
        ..port = 0;
      target.ref.serviceClassId.setGUID(_sppServiceClass);
      if (ws.connect(SOCKET(socket), target.cast(), sizeOf<SOCKADDR_BTH>()).value != 0) {
        closesocket(SOCKET(socket));
        return null;
      }
      _setNonBlocking(socket);
      return socket;
    } finally {
      calloc.free(target);
    }
  }

  static void _setNonBlocking(int socket) {
    final enable = calloc<Uint32>()..value = 1;
    ioctlsocket(SOCKET(socket), _fionbio, enable);
    calloc.free(enable);
  }

  /// Second chance for a name the inquiry didn't resolve; Windows often has it by now.
  static String _lookupName(int address) {
    final info = calloc<BLUETOOTH_DEVICE_INFO>();
    try {
      info.ref
        ..dwSize = sizeOf<BLUETOOTH_DEVICE_INFO>()
        ..Address.Anonymous.ullLong = address;
      return BluetoothGetDeviceInfo(null, info) == ERROR_SUCCESS ? info.ref.szName : '';
    } finally {
      calloc.free(info);
    }
  }

  // ----- HELPERS -----

  /// Class of Device: major class "Imaging" (0x06) with the "Printer" bit (0x80) in the minor class.
  static bool _isPrinterClass(int deviceClass) => (deviceClass >> 8) & 0x1F == 0x06 && deviceClass & 0x80 != 0;

  static const _sppServiceClass = '{00001101-0000-1000-8000-00805F9B34FB}';
  static const _rfcommProtocol = 3; // BTHPROTO_RFCOMM

  // Not exported by package:win32.
  static final _fionbio = 0x8004667E.toSigned(32);
  static const _wouldBlock = 10035; // WSAEWOULDBLOCK

  static int socket_(int af, WINSOCK_SOCKET_TYPE type, int protocol) => socket(af, type, protocol).value;

  static String _formatAddress(int address) => [
    for (var shift = 40; shift >= 0; shift -= 8) ((address >> shift) & 0xFF).toRadixString(16).padLeft(2, '0'),
  ].join(':').toUpperCase();

  static int _parseAddress(String id) => int.parse(id.replaceAll(':', ''), radix: 16);

  // win32 does not bind WSAStartup; it is reference counted, so calling it per isolate is fine.
  static final _wsaStartup = DynamicLibrary.open('ws2_32.dll')
      .lookupFunction<Int32 Function(Uint16, Pointer<Uint8>), int Function(int, Pointer<Uint8>)>('WSAStartup');

  static void _ensureWinsock() {
    final data = calloc<Uint8>(512); // >= sizeof(WSADATA)
    _wsaStartup(0x0202, data);
    calloc.free(data);
  }
}
