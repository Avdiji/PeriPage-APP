/// A printer the app can talk to, before connecting.
final class DeviceCandidate {
  final String id;
  final String name;
  final String? detail;

  const DeviceCandidate({required this.id, required this.name, this.detail});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'detail': detail};

  static DeviceCandidate fromJson(Map<String, dynamic> json) =>
      DeviceCandidate(id: json['id'] as String, name: json['name'] as String, detail: json['detail'] as String?);
}

/// The connected printer.
final class DeviceEntity {
  final String id;
  final String name;
  final int widthDots;
  final int dpi;
  final bool compressedRasterOnly;
  final int? battery;
  final String? firmware;
  final String? serial;

  const DeviceEntity({
    required this.id,
    required this.name,
    required this.widthDots,
    required this.dpi,
    this.compressedRasterOnly = false,
    this.battery,
    this.firmware,
    this.serial,
  });

  DeviceEntity copyWith({int? battery}) => DeviceEntity(
    id: id,
    name: name,
    widthDots: widthDots,
    dpi: dpi,
    compressedRasterOnly: compressedRasterOnly,
    battery: battery ?? this.battery,
    firmware: firmware,
    serial: serial,
  );
}
