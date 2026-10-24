import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peripage_app/config/constants.dart';
import 'package:peripage_app/services/transport/models/discovered_device_in.dart';
import 'package:peripage_app/services/transport/printer_transport.dart';

/// Thrown by [PrinterClient.sendChunked] when its `isCancelled` callback returns true.
final class TransferCancelledException implements Exception {
  const TransferCancelledException();
}

/// Serialises access to a [PrinterTransport]: queries wait for their reply, writes are chunked.
///
/// The printer answers without any framing, so only one request may be in flight at a time.
/// In debug builds every exchange is logged as hex (`[printer] → 10 FF 40` / `← 01`).
final class PrinterClient {
  final PrinterTransport _transport;
  Future<void> _queue = Future.value();

  PrinterClient(this._transport);

  bool get isConnected => _transport.isConnected;

  Future<List<DiscoveredDeviceIn>> discover() => _transport.discover();

  Future<void> connect(DiscoveredDeviceIn device) => _transport.connect(device);

  Future<void> disconnect() => _transport.disconnect();

  /// Sends [command] and collects the reply until the line stays quiet for [settle].
  /// Returns an empty list if nothing arrives within [timeout].
  Future<Uint8List> request(
    Uint8List command, {
    Duration settle = Timings.replySettle,
    Duration timeout = Timings.replyTimeout,
  }) {
    return _exclusive(() async {
      final buffer = BytesBuilder();
      final done = Completer<Uint8List>();
      Timer? settleTimer;

      final sub = _transport.incoming.listen((chunk) {
        buffer.add(chunk);
        settleTimer?.cancel();
        settleTimer = Timer(settle, () {
          if (!done.isCompleted) done.complete(buffer.takeBytes());
        });
      });
      final timeoutTimer = Timer(timeout, () {
        if (!done.isCompleted) done.complete(buffer.takeBytes());
      });

      try {
        _log('→ ${_hex(command)}');
        await _transport.write(command);
        final reply = await done.future;
        _log(reply.isEmpty ? '← (no reply)' : '← ${_hex(reply)}  ${_ascii(reply)}');
        return reply;
      } finally {
        settleTimer?.cancel();
        timeoutTimer.cancel();
        await sub.cancel();
      }
    });
  }

  /// Sends [command] without waiting for a reply.
  Future<void> send(Uint8List command) => _exclusive(() {
    _log('→ ${_hex(command)}');
    return _transport.write(command);
  });

  /// Writes [data] in chunks of [Timings.chunkSize] and reports the bytes written so far.
  /// Holds the line for the whole payload so status polls cannot interleave.
  /// Checks [isCancelled] before every chunk and throws [TransferCancelledException].
  Future<void> sendChunked(Uint8List data, {void Function(int sent)? onProgress, bool Function()? isCancelled}) {
    return _exclusive(() async {
      _log('→ ${data.length} bytes (${_hex(Uint8List.sublistView(data, 0, data.length.clamp(0, 12)))} …)');
      var offset = 0;
      while (offset < data.length) {
        if (isCancelled?.call() ?? false) {
          _log('✕ cancelled after $offset of ${data.length} bytes');
          throw const TransferCancelledException();
        }
        final end = (offset + Timings.chunkSize).clamp(0, data.length);
        await _transport.write(Uint8List.sublistView(data, offset, end));
        offset = end;
        onProgress?.call(offset);
        await Future<void>.delayed(Timings.chunkPause);
      }
    });
  }

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('[printer] $message');
  }

  static String _hex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');

  static String _ascii(Uint8List bytes) =>
      '"${String.fromCharCodes(bytes.map((b) => b >= 0x20 && b < 0x7F ? b : 0x2E))}"';
}

final printerClientProvider = Provider<PrinterClient>((Ref ref) {
  return PrinterClient(ref.watch(printerTransportProvider));
});
