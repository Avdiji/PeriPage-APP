import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peripage_app/core/device/state/device_provider.dart';
import 'package:peripage_app/core/history/domain/history_entry.dart';
import 'package:peripage_app/core/printing/data/print_repo_impl.dart';
import 'package:peripage_app/core/printing/domain/print_job_entity.dart';
import 'package:peripage_app/core/printing/domain/print_settings.dart';

final class DraftState {
  final DraftEntity? draft;
  final PrintSettings settings;
  final bool picking;

  const DraftState({this.draft, this.settings = const PrintSettings(), this.picking = false});

  DraftState copyWith({DraftEntity? draft, PrintSettings? settings, bool? picking}) =>
      DraftState(draft: draft ?? this.draft, settings: settings ?? this.settings, picking: picking ?? this.picking);
}

final class DraftNotifier extends Notifier<DraftState> {
  @override
  DraftState build() => const DraftState();

  Future<void> pick() async {
    state = state.copyWith(picking: true);
    try {
      final draft = await ref.read(printRepoProvider).pickDraft();
      if (draft == null) return;
      final density = ref.read(deviceSettingsProvider).valueOrNull?.density.index ?? 1;
      state = DraftState(
        draft: draft,
        settings: state.settings.copyWith(
          density: density,
          pages: PageSelection.all,
          pageSpec: draft.pageCount == 1 ? '1' : '1-${draft.pageCount}',
          currentPage: 0,
        ),
      );
    } finally {
      state = state.copyWith(picking: false);
    }
  }

  void update(PrintSettings settings) => state = state.copyWith(settings: settings);

  /// Opens a history entry with its stored settings.
  void openFromHistory(HistoryEntry entry) => state = DraftState(draft: entry.draft, settings: entry.settings);
}

final draftProvider = NotifierProvider<DraftNotifier, DraftState>(DraftNotifier.new);

/// Preview of the page currently shown in the draft. Only re-renders when output-relevant settings change.
final previewProvider = FutureProvider.autoDispose<PreviewBitmap?>((Ref ref) async {
  final draft = ref.watch(draftProvider.select((s) => s.draft));
  final key = ref.watch(
    draftProvider.select((s) => (s.settings.dither, s.settings.scale, s.settings.rotation, s.settings.currentPage)),
  );
  final width = ref.watch(deviceProvider.select((d) => d.valueOrNull?.widthDots ?? 384));
  if (draft == null) return null;

  final settings = ref.read(draftProvider).settings;
  return ref.read(printRepoProvider).renderPage(draft, settings, key.$4, width);
});
