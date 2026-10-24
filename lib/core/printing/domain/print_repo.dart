import 'package:peripage_app/core/device/domain/device_entity.dart';
import 'package:peripage_app/core/device/domain/device_settings.dart';
import 'package:peripage_app/core/printing/domain/print_job_control.dart';
import 'package:peripage_app/core/printing/domain/print_job_entity.dart';
import 'package:peripage_app/core/printing/domain/print_progress.dart';
import 'package:peripage_app/core/printing/domain/print_settings.dart';

abstract interface class PrintRepo {
  /// Lets the user pick a file and stores a private copy. Null if cancelled.
  Future<DraftEntity?> pickDraft();

  /// Renders [pageIndex] exactly as it will be printed on a head [widthDots] wide.
  Future<PreviewBitmap> renderPage(
    DraftEntity draft,
    PrintSettings settings,
    int pageIndex,
    int widthDots,
  );

  /// Sends the job, then waits for the printer to report it finished. Emits [PrintPhase.sending] progress,
  /// one [PrintPhase.printing] event and a final [PrintPhase.done]. On single sheets every page waits for
  /// its sheet ([PrintPhase.waitingForPaper], [PrintPhase.paperReady]). Errors if the printer reports a
  /// problem, or with a PrintCancelledException once [control] is cancelled.
  Stream<PrintProgress> print(PrintJobEntity job, DeviceEntity device, PaperType paper, PrintJobControl control);
}
