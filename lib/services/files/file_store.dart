import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Picks printable files and keeps private copies of them so History can reprint later.
final class FileStore {
  static const printableExtensions = ['png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif', 'pdf'];

  Directory? _root;

  /// Opens the system picker and copies the chosen file into app storage. Returns null if cancelled.
  Future<File?> pickAndImport() async {
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: printableExtensions);
    if (picked.isEmpty) return null;
    final file = picked.first;
    return import(file.name, await file.xFile.readAsBytes());
  }

  Future<File> import(String name, Uint8List bytes) async {
    final dir = await _dir('files');
    final safeName = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${dir.path}${Platform.pathSeparator}${DateTime.now().microsecondsSinceEpoch}_$safeName');
    return file.writeAsBytes(bytes, flush: true);
  }

  Future<File> writeThumbnail(String id, Uint8List png) async {
    final dir = await _dir('thumbs');
    return File('${dir.path}${Platform.pathSeparator}$id.png').writeAsBytes(png, flush: true);
  }

  Future<File> historyFile() async {
    final root = await _rootDir();
    return File('${root.path}${Platform.pathSeparator}history.json');
  }

  Future<void> deleteIfExists(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<Directory> _dir(String name) async {
    final root = await _rootDir();
    return Directory('${root.path}${Platform.pathSeparator}$name').create(recursive: true);
  }

  Future<Directory> _rootDir() async => _root ??= await getApplicationSupportDirectory();
}

final fileStoreProvider = Provider<FileStore>((Ref ref) => FileStore());
