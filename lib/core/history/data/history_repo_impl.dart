import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peripage_app/core/history/domain/history_entry.dart';
import 'package:peripage_app/core/history/domain/history_repo.dart';
import 'package:peripage_app/core/printing/domain/print_job_entity.dart';
import 'package:peripage_app/services/files/file_store.dart';
import 'package:peripage_app/services/imaging/image_scaler.dart';
import 'package:peripage_app/services/imaging/mono_bitmap.dart';
import 'package:peripage_app/services/storage/history_store.dart';

final class HistoryRepoImpl implements HistoryRepo {
  final HistoryStore _store;
  final FileStore _files;
  const HistoryRepoImpl(this._store, this._files);

  @override
  Future<List<HistoryEntry>> list() async {
    final raw = await _store.readAll();
    return [for (final json in raw) HistoryEntry.fromJson(json)];
  }

  @override
  Future<HistoryEntry> record(PrintJobEntity job, String deviceName, PreviewBitmap firstPage) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final png = ImageScaler.thumbnailPng(MonoBitmap(firstPage.width, firstPage.height, firstPage.pixels));
    final thumb = await _files.writeThumbnail(id, png);

    final entry = HistoryEntry(
      id: id,
      draft: job.draft,
      settings: job.settings,
      deviceName: deviceName,
      printedAt: DateTime.now(),
      thumbnailPath: thumb.path,
    );
    final all = await _store.readAll();
    await _store.writeAll([entry.toJson(), ...all]);
    return entry;
  }

  @override
  Future<void> delete(HistoryEntry entry, {bool keepFile = false}) async {
    final remaining = (await list()).where((e) => e.id != entry.id).toList();
    await _store.writeAll([for (final e in remaining) e.toJson()]);
    await _files.deleteIfExists(entry.thumbnailPath);

    // The source file may be shared by several prints of the same draft.
    if (!keepFile && !remaining.any((e) => e.draft.path == entry.draft.path)) {
      await _files.deleteIfExists(entry.draft.path);
    }
  }
}

final historyRepoProvider = Provider<HistoryRepo>((Ref ref) {
  return HistoryRepoImpl(ref.watch(historyStoreProvider), ref.watch(fileStoreProvider));
});
