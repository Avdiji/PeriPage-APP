import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peripage_app/services/files/file_store.dart';

/// History persisted as a JSON array, newest first.
final class HistoryStore {
  final FileStore _files;
  const HistoryStore(this._files);

  Future<List<Map<String, dynamic>>> readAll() async {
    final file = await _files.historyFile();
    if (!await file.exists()) return [];
    try {
      final decoded = jsonDecode(await file.readAsString()) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } on FormatException {
      return [];
    }
  }

  Future<void> writeAll(List<Map<String, dynamic>> entries) async {
    final file = await _files.historyFile();
    await file.writeAsString(jsonEncode(entries), flush: true);
  }
}

final historyStoreProvider = Provider<HistoryStore>((Ref ref) => HistoryStore(ref.watch(fileStoreProvider)));
