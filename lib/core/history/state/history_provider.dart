import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peripage_app/core/history/data/history_repo_impl.dart';
import 'package:peripage_app/core/history/domain/history_entry.dart';
import 'package:peripage_app/core/printing/domain/print_job_entity.dart';

final class HistoryNotifier extends AsyncNotifier<List<HistoryEntry>> {
  @override
  FutureOr<List<HistoryEntry>> build() => ref.read(historyRepoProvider).list();

  Future<void> record(PrintJobEntity job, String deviceName, PreviewBitmap firstPage) async {
    final entry = await ref.read(historyRepoProvider).record(job, deviceName, firstPage);
    state = AsyncData([entry, ...?state.valueOrNull]);
  }

  Future<void> delete(HistoryEntry entry, {bool keepFile = false}) async {
    state = AsyncData([...?state.valueOrNull?.where((e) => e.id != entry.id)]);
    await ref.read(historyRepoProvider).delete(entry, keepFile: keepFile);
  }
}

final historyProvider = AsyncNotifierProvider<HistoryNotifier, List<HistoryEntry>>(HistoryNotifier.new);
