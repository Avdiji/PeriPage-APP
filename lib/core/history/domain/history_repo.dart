import 'package:peripage_app/core/history/domain/history_entry.dart';
import 'package:peripage_app/core/printing/domain/print_job_entity.dart';

abstract interface class HistoryRepo {
  /// Newest first.
  Future<List<HistoryEntry>> list();

  /// Stores a finished job together with a thumbnail of its first page.
  Future<HistoryEntry> record(PrintJobEntity job, String deviceName, PreviewBitmap firstPage);

  /// Removes the entry. Its source file is deleted too unless another entry uses it or [keepFile] is set.
  Future<void> delete(HistoryEntry entry, {bool keepFile = false});
}
