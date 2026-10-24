/// A printer endpoint found by a transport: a bonded Bluetooth device (Android) or a COM port (Windows).
final class DiscoveredDeviceIn {
  /// Bluetooth MAC address or COM port name. Used to reconnect.
  final String id;
  final String name;

  /// Extra information for the list (e.g. port description).
  final String? detail;

  const DiscoveredDeviceIn({required this.id, required this.name, this.detail});
}
