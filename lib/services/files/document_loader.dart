import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:pdfx/pdfx.dart';

/// Loads images and PDF pages as decoded bitmaps.
///
/// Decoded pages are cached (a few entries), so changing dither, density or rotation doesn't decode or
/// re-render the source again.
final class DocumentLoader {
  static const _cacheSize = 6;
  final _cache = <String, img.Image>{}; // insertion-ordered: first key = least recently used

  static bool isPdf(String path) => path.toLowerCase().endsWith('.pdf');

  Future<int> pageCount(String path) async {
    if (!isPdf(path)) return 1;
    final doc = await PdfDocument.openFile(path);
    try {
      return doc.pagesCount;
    } finally {
      await doc.close();
    }
  }

  /// Page [pageIndex] (0-based). PDF pages are rasterised so that, after [quarterTurns] clockwise turns, the
  /// page is exactly [targetWidth] pixels wide — no oversized render to shrink later. Images are returned as
  /// decoded; scaling happens in the imaging service.
  Future<img.Image> loadPage(String path, int pageIndex, {required int targetWidth, required int quarterTurns}) async {
    if (!isPdf(path)) {
      return _cached(path, () async {
        final decoded = img.decodeImage(await File(path).readAsBytes());
        if (decoded == null) throw FormatException('Unsupported image: $path');
        return decoded;
      });
    }

    final doc = await PdfDocument.openFile(path);
    try {
      final page = await doc.getPage(pageIndex + 1);
      try {
        // Sideways pages: the page's height becomes the printed width.
        final aspect = page.width / page.height;
        final renderWidth = quarterTurns.isOdd ? (targetWidth * aspect).round() : targetWidth;
        return await _cached('$path#$pageIndex#$renderWidth', () async {
          final rendered = await page.render(
            width: renderWidth.toDouble(),
            height: renderWidth / aspect,
            format: PdfPageImageFormat.png,
            backgroundColor: '#FFFFFF',
            forPrint: true,
          );
          final decoded = rendered == null ? null : img.decodePng(rendered.bytes);
          if (decoded == null) throw FormatException('Could not render page ${pageIndex + 1}');
          return decoded;
        });
      } finally {
        await page.close();
      }
    } finally {
      await doc.close();
    }
  }

  Future<img.Image> _cached(String key, Future<img.Image> Function() load) async {
    final hit = _cache.remove(key);
    if (hit != null) return _cache[key] = hit; // re-insert as most recent
    final value = await load();
    _cache[key] = value;
    while (_cache.length > _cacheSize) {
      _cache.remove(_cache.keys.first);
    }
    return value;
  }
}

final documentLoaderProvider = Provider<DocumentLoader>((Ref ref) => DocumentLoader());
