import 'dart:typed_data';

import 'package:peripage_app/core/printing/domain/print_settings.dart';

/// A file the user picked, stored in app storage.
final class DraftEntity {
  final String path;
  final String fileName;
  final bool isPdf;
  final int pageCount;

  const DraftEntity({required this.path, required this.fileName, required this.isPdf, required this.pageCount});

  Map<String, dynamic> toJson() => {'path': path, 'fileName': fileName, 'isPdf': isPdf, 'pageCount': pageCount};

  static DraftEntity fromJson(Map<String, dynamic> json) => DraftEntity(
    path: json['path'] as String,
    fileName: json['fileName'] as String,
    isPdf: json['isPdf'] as bool? ?? false,
    pageCount: json['pageCount'] as int? ?? 1,
  );
}

final class PrintJobEntity {
  final DraftEntity draft;
  final PrintSettings settings;

  const PrintJobEntity({required this.draft, required this.settings});
}

/// 1-bit page as it will be printed (1 = black), used for previews and thumbnails.
final class PreviewBitmap {
  final int width;
  final int height;
  final Uint8List pixels;

  const PreviewBitmap({required this.width, required this.height, required this.pixels});
}
