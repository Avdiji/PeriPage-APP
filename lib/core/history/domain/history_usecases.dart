import 'package:peripage_app/core/history/domain/history_entry.dart';
import 'package:peripage_app/core/printing/domain/print_job_entity.dart';

/// Rebuilds the exact job that produced [entry].
final class ReprintUseCase {
  const ReprintUseCase();

  PrintJobEntity call(HistoryEntry entry) => PrintJobEntity(draft: entry.draft, settings: entry.settings);
}
