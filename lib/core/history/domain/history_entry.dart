import 'package:peripage_app/core/printing/domain/print_job_entity.dart';
import 'package:peripage_app/core/printing/domain/print_settings.dart';

final class HistoryEntry {
  final String id;
  final DraftEntity draft;
  final PrintSettings settings;
  final String deviceName;
  final DateTime printedAt;
  final String? thumbnailPath;

  const HistoryEntry({
    required this.id,
    required this.draft,
    required this.settings,
    required this.deviceName,
    required this.printedAt,
    this.thumbnailPath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'draft': draft.toJson(),
    'settings': settings.toJson(),
    'deviceName': deviceName,
    'printedAt': printedAt.toIso8601String(),
    'thumbnailPath': thumbnailPath,
  };

  static HistoryEntry fromJson(Map<String, dynamic> json) => HistoryEntry(
    id: json['id'] as String,
    draft: DraftEntity.fromJson(json['draft'] as Map<String, dynamic>),
    settings: PrintSettings.fromJson(json['settings'] as Map<String, dynamic>),
    deviceName: json['deviceName'] as String? ?? '',
    printedAt: DateTime.tryParse(json['printedAt'] as String? ?? '') ?? DateTime.now(),
    thumbnailPath: json['thumbnailPath'] as String?,
  );
}
