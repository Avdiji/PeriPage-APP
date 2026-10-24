enum Density {
  light('Light'),
  normal('Normal'),
  dark('Dark');

  final String label;
  const Density(this.label);
}

enum PaperType {
  roll('Roll', 0, 'Continuous paper, a short feed after each print.'),
  labels('Label', 2, 'Sticker labels with gaps; advances to the next label.'),
  sheet('Sheet', 3, 'Single A4 sheets; advances to the next sheet after each page.'),
  folded('Folded', 1, 'Fan-fold A4 stack; advances to the next fold after each page.');

  final String label;

  /// Value sent with `10 FF 10 03` (codes from the official app).
  final int code;
  final String description;
  const PaperType(this.label, this.code, this.description);

  /// Whether the printer positions the next page itself (form feed) instead of feeding a fixed length.
  bool get advancesToNextPage => this != roll;

  /// Paper types that make sense for a printer [widthDots] wide.
  static List<PaperType> choicesFor(int widthDots) => widthDots >= 1000 ? const [sheet, folded, roll] : const [roll, labels];
}

/// Printer-level defaults, applied on connect and used to pre-fill new drafts.
final class DeviceSettings {
  static const autoOffChoices = [15, 30, 60, 0];

  final Density density;
  final PaperType paperType;

  /// Minutes until the printer powers off, 0 = never.
  final int autoOffMinutes;
  final bool reconnectOnStart;

  /// Single sheets: continue as soon as the next sheet is detected (true) or ask first (false).
  final bool autoContinueSheets;

  const DeviceSettings({
    this.density = Density.normal,
    this.paperType = PaperType.roll,
    this.autoOffMinutes = 30,
    this.reconnectOnStart = true,
    this.autoContinueSheets = true,
  });

  DeviceSettings copyWith({
    Density? density,
    PaperType? paperType,
    int? autoOffMinutes,
    bool? reconnectOnStart,
    bool? autoContinueSheets,
  }) => DeviceSettings(
    density: density ?? this.density,
    paperType: paperType ?? this.paperType,
    autoOffMinutes: autoOffMinutes ?? this.autoOffMinutes,
    reconnectOnStart: reconnectOnStart ?? this.reconnectOnStart,
    autoContinueSheets: autoContinueSheets ?? this.autoContinueSheets,
  );

  Map<String, dynamic> toJson() => {
    'density': density.name,
    'paperType': paperType.name,
    'autoOffMinutes': autoOffMinutes,
    'reconnectOnStart': reconnectOnStart,
    'autoContinueSheets': autoContinueSheets,
  };

  static DeviceSettings fromJson(Map<String, dynamic> json) => DeviceSettings(
    density: Density.values.asNameMap()[json['density']] ?? Density.normal,
    paperType: PaperType.values.asNameMap()[json['paperType']] ?? PaperType.roll,
    autoOffMinutes: json['autoOffMinutes'] as int? ?? 30,
    reconnectOnStart: json['reconnectOnStart'] as bool? ?? true,
    autoContinueSheets: json['autoContinueSheets'] as bool? ?? true,
  );
}
