import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:peripage_app/core/device/domain/device_entity.dart';
import 'package:peripage_app/core/device/domain/device_settings.dart';
import 'package:peripage_app/core/printing/domain/print_job_entity.dart';
import 'package:peripage_app/core/printing/domain/print_progress.dart';
import 'package:peripage_app/core/printing/domain/print_cancelled_exception.dart';
import 'package:peripage_app/core/printing/domain/print_job_control.dart';
import 'package:peripage_app/core/printing/domain/print_repo.dart';
import 'package:peripage_app/core/printing/domain/print_settings.dart';
import 'package:peripage_app/services/files/document_loader.dart';
import 'package:peripage_app/services/files/file_store.dart';
import 'package:peripage_app/services/imaging/dithering.dart';
import 'package:peripage_app/services/imaging/image_scaler.dart';
import 'package:peripage_app/services/imaging/mono_bitmap.dart';
import 'package:peripage_app/services/protocol/commands.dart';
import 'package:peripage_app/services/protocol/raster_encoder.dart';
import 'package:peripage_app/services/protocol/reply_parser.dart';
import 'package:peripage_app/services/transport/printer_client.dart';

final class PrintRepoImpl implements PrintRepo {
  final FileStore _files;
  final DocumentLoader _loader;
  final PrinterClient _client;
  const PrintRepoImpl(this._files, this._loader, this._client);

  @override
  Future<DraftEntity?> pickDraft() async {
    final file = await _files.pickAndImport();
    if (file == null) return null;
    final name = file.uri.pathSegments.last.replaceFirst(RegExp(r'^\d+_'), '');
    return DraftEntity(
      path: file.path,
      fileName: name,
      isPdf: DocumentLoader.isPdf(file.path),
      pageCount: await _loader.pageCount(file.path),
    );
  }

  @override
  Future<PreviewBitmap> renderPage(
    DraftEntity draft,
    PrintSettings settings,
    int pageIndex,
    int widthDots,
  ) async {
    final bitmap = await _render(draft, settings, pageIndex, widthDots);
    return PreviewBitmap(width: bitmap.width, height: bitmap.height, pixels: bitmap.pixels);
  }

  @override
  Stream<PrintProgress> print(PrintJobEntity job, DeviceEntity device, PaperType paper, PrintJobControl control) async* {
    final settings = job.settings;
    final pages = settings.pageIndices(job.draft.pageCount);
    var pagesSent = 0;
    PrintCancelledException cancelled({bool midPage = false}) =>
        PrintCancelledException(midPage: midPage, pagesSent: pagesSent > 0);

    // Render every page first so the progress total is known and the head never waits on decoding.
    final frames = <Uint8List>[];
    final pageLines = <int>[];
    for (final page in pages) {
      if (control.cancelled) throw cancelled();
      final bitmap = await _render(job.draft, settings, page, device.widthDots);
      frames.add(_frame(bitmap, settings.feedDots, paper));
      pageLines.add(bitmap.height);
    }
    final total = frames.fold<int>(0, (sum, f) => sum + f.length) * settings.copies;

    // Single sheets go one page at a time: the A40 prints the first sheet and then drops everything else,
    // so each further page is only sent once its sheet is in.
    final sheetBySheet = paper == PaperType.sheet;
    if (!sheetBySheet) {
      // Refuse early instead of streaming megabytes into a printer that cannot print.
      _throwIfProblem(await _status(), paper);
    }
    await _client.request(Commands.setDensity(settings.density), timeout: _ackTimeout);

    var sent = 0;
    PrintProgress progress(int index, int copy, int sentBytes) => PrintProgress(
      fileName: job.draft.fileName,
      sentBytes: sentBytes,
      totalBytes: total,
      page: index + 1,
      pageCount: frames.length,
      copy: copy,
      copies: settings.copies,
      pageLines: pageLines,
    );
    var last = progress(0, 1, 0);

    for (var copy = 1; copy <= settings.copies; copy++) {
      for (var i = 0; i < frames.length; i++) {
        final firstSheet = copy == 1 && i == 0;
        if (sheetBySheet) {
          if (!firstSheet) await _awaitSheetEjected(control, cancelled);
          yield* _awaitSheet(control, progress(i, copy, sent), firstSheet: firstSheet, cancelled: cancelled);
        }

        final controller = StreamController<int>();
        final done = _client
            .sendChunked(frames[i], onProgress: controller.add, isCancelled: () => control.cancelled)
            .whenComplete(controller.close);
        final base = sent;
        await for (final pageSent in controller.stream) {
          yield last = progress(i, copy, base + pageSent);
        }
        try {
          await done;
        } on TransferCancelledException {
          // The printer now holds half a raster frame; the caller resets the connection.
          throw cancelled(midPage: true);
        }
        sent += frames[i].length;
        pagesSent++;
      }
    }

    yield last.copyWith(phase: PrintPhase.printing);
    yield last.copyWith(phase: PrintPhase.done, confirmed: await _waitUntilPrinted(control, paper, cancelled));
  }

  static const _ackTimeout = Duration(milliseconds: 600);
  static const _printTimeout = Duration(seconds: 90);
  static const _pollPause = Duration(milliseconds: 700);

  /// Gives a freshly inserted sheet time to be pulled in and aligned before data arrives.
  static const _sheetSettle = Duration(milliseconds: 1500);

  Future<RawPrinterState> _status() async =>
      ReplyParser.status(await _client.request(Commands.queryStatus(), timeout: const Duration(seconds: 1)));

  /// Makes sure a sheet is in before the next page. Emits [PrintPhase.waitingForPaper] while there is none
  /// and, unless auto-continue is on, [PrintPhase.paperReady] until the user continues. The very first sheet
  /// is never asked about when it is already in — pressing Print was the confirmation.
  Stream<PrintProgress> _awaitSheet(
    PrintJobControl control,
    PrintProgress next, {
    required bool firstSheet,
    required PrintCancelledException Function() cancelled,
  }) async* {
    var state = await _status();
    if (state == RawPrinterState.lowBattery || state == RawPrinterState.overheated) _throwIfProblem(state, PaperType.sheet);
    final alreadyIn = state != RawPrinterState.noPaper;
    if (alreadyIn && firstSheet) return;

    if (!alreadyIn) {
      yield next.copyWith(phase: PrintPhase.waitingForPaper);
      while (state == RawPrinterState.noPaper || state == RawPrinterState.unknown || state == RawPrinterState.busy) {
        if (control.cancelled) throw cancelled();
        await Future<void>.delayed(_pollPause);
        state = await _status();
        if (state == RawPrinterState.lowBattery || state == RawPrinterState.overheated) _throwIfProblem(state, PaperType.sheet);
      }
    }

    if (control.autoContinue) {
      await Future<void>.delayed(_sheetSettle);
    } else {
      // Arm the gate before the prompt goes out, so an immediate Continue / Cancel can't be missed.
      final answered = control.waitForUser();
      yield next.copyWith(phase: PrintPhase.paperReady);
      await answered;
    }
    if (control.cancelled) throw cancelled();
  }

  /// After a page was sent on single sheets: waits until that sheet has been printed and ejected.
  Future<void> _awaitSheetEjected(PrintJobControl control, PrintCancelledException Function() cancelled) async {
    final deadline = DateTime.now().add(_printTimeout);
    var sawBusy = false;
    var unanswered = 0;
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    while (DateTime.now().isBefore(deadline)) {
      if (control.cancelled) throw cancelled();
      final reply = await _client.request(Commands.queryStatus(), timeout: const Duration(seconds: 1));
      if (reply.isEmpty) {
        // Silence is normal while the head runs; minutes of it are not.
        if (++unanswered >= 20) throw StateError('The printer stopped responding.');
      } else {
        unanswered = 0;
        final state = ReplyParser.status(reply);
        if (state == RawPrinterState.noPaper) return; // ejected
        if (state == RawPrinterState.busy) sawBusy = true;
        if (state == RawPrinterState.idle && sawBusy) return;
        if (state == RawPrinterState.lowBattery || state == RawPrinterState.overheated) _throwIfProblem(state, PaperType.sheet);
      }
      await Future<void>.delayed(_pollPause);
    }
    throw StateError('The page took too long to print.');
  }

  /// Polls `10 FF 40` until the printer is done. Returns false if it never answers or never finishes.
  /// Cancelling only stops waiting — the data is already in the printer.
  ///
  /// With sheets (or folds) "no paper" at the end is success: the printed sheet has been ejected. Paper was
  /// present when the page started (checked before sending), so it can only have gone by being printed.
  Future<bool> _waitUntilPrinted(
    PrintJobControl control,
    PaperType paper,
    PrintCancelledException Function() cancelled,
  ) async {
    final deadline = DateTime.now().add(_printTimeout);
    var unanswered = 0;
    // Give the printer a moment to start; right after the end command it may still report idle.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    while (DateTime.now().isBefore(deadline)) {
      if (control.cancelled) throw cancelled();
      // While the head is busy the printer often doesn't answer at all, so silence alone isn't failure.
      final reply = await _client.request(Commands.queryStatus(), timeout: const Duration(seconds: 1));
      if (reply.isEmpty) {
        if (++unanswered >= 8) return false;
      } else {
        unanswered = 0;
        final state = ReplyParser.status(reply);
        if (state == RawPrinterState.idle) return true;
        if (state == RawPrinterState.noPaper && paper != PaperType.roll) return true;
        _throwIfProblem(state, paper);
      }
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    return false;
  }

  static void _throwIfProblem(RawPrinterState state, PaperType paper) {
    final problem = switch (state) {
      RawPrinterState.noPaper when paper == PaperType.sheet => 'No paper detected. Insert a sheet and try again.',
      RawPrinterState.noPaper => 'The printer is out of paper.',
      RawPrinterState.lowBattery => 'The printer battery is too low to print.',
      RawPrinterState.overheated => 'The printer is overheated. Let it cool down.',
      _ => null,
    };
    if (problem != null) throw StateError(problem);
  }

  /// One page as the official app sends it: start, wake, raster, then either a fixed feed (roll) or a
  /// form feed that positions the next sheet / label, then end.
  static Uint8List _frame(MonoBitmap bitmap, int feedDots, PaperType paper) {
    return (BytesBuilder(copy: false)
          ..add(Commands.startJob())
          ..add(Commands.wake())
          ..add(RasterEncoder.gsv0(bitmap))
          ..add(paper.advancesToNextPage ? Commands.nextPage() : Commands.feed(feedDots))
          ..add(Commands.endJob()))
        .toBytes();
  }

  Future<MonoBitmap> _render(
    DraftEntity draft,
    PrintSettings settings,
    int pageIndex,
    int widthDots,
  ) async {
    // PDFs are rendered straight at print size; decoded pages are cached by the loader.
    final page = await _loader.loadPage(draft.path, pageIndex, targetWidth: widthDots, quarterTurns: settings.rotation);
    return Isolate.run(() => _process(page, settings, widthDots));
  }

  static MonoBitmap _process(img.Image page, PrintSettings settings, int widthDots) {
    final gray = ImageScaler.toPrintGray(
      page,
      width: widthDots,
      fitWidth: settings.scale == ScaleMode.fitWidth,
      quarterTurns: settings.rotation,
    );
    final mode = switch (settings.dither) {
      Dither.off => DitherMode.off,
      Dither.floyd => DitherMode.floyd,
      Dither.atkinson => DitherMode.atkinson,
    };
    return Dithering.apply(gray, mode);
  }
}

final printRepoProvider = Provider<PrintRepo>((Ref ref) {
  return PrintRepoImpl(ref.watch(fileStoreProvider), ref.watch(documentLoaderProvider), ref.watch(printerClientProvider));
});
