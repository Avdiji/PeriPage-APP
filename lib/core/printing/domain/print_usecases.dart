import 'package:peripage_app/core/device/domain/device_entity.dart';
import 'package:peripage_app/core/device/domain/device_settings.dart';
import 'package:peripage_app/core/printing/domain/print_job_control.dart';
import 'package:peripage_app/core/printing/domain/print_job_entity.dart';
import 'package:peripage_app/core/printing/domain/print_progress.dart';
import 'package:peripage_app/core/printing/domain/print_repo.dart';

final class PrintJobUseCase {
  final PrintRepo _repo;
  const PrintJobUseCase(this._repo);

  Stream<PrintProgress> call(PrintJobEntity job, DeviceEntity? device, PaperType paper, PrintJobControl control) {
    if (device == null) return Stream.error(StateError('No printer connected.'));
    if (job.settings.pageIndices(job.draft.pageCount).isEmpty) return Stream.error(StateError('No valid pages selected.'));
    return _repo.print(job, device, paper, control);
  }
}
