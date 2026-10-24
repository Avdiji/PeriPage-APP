enum PrintPhase {
  /// Data is being transferred to the printer.
  sending,

  /// Single sheets: the previous sheet is done, the printer needs the next one ([PrintProgress.page]).
  waitingForPaper,

  /// Single sheets, "ask before continuing": the next sheet is in, waiting for the user to continue.
  paperReady,

  /// Everything was sent; waiting for the printer to report that it is idle again.
  printing,

  /// The job is over. See [PrintProgress.confirmed].
  done,
}

final class PrintProgress {
  final String fileName;
  final PrintPhase phase;
  final int sentBytes;
  final int totalBytes;

  /// 1-based, for display.
  final int page;
  final int pageCount;
  final int copy;
  final int copies;

  /// For [PrintPhase.done]: whether the printer reported it finished. False means it never answered.
  final bool confirmed;

  /// Height in dot-lines of each page of one copy, in print order. Printing time is proportional to it.
  final List<int> pageLines;

  const PrintProgress({
    required this.fileName,
    required this.sentBytes,
    required this.totalBytes,
    required this.page,
    required this.pageCount,
    required this.copy,
    required this.copies,
    this.phase = PrintPhase.sending,
    this.confirmed = false,
    this.pageLines = const [],
  });

  PrintProgress copyWith({PrintPhase? phase, bool? confirmed}) => PrintProgress(
    fileName: fileName,
    sentBytes: sentBytes,
    totalBytes: totalBytes,
    page: page,
    pageCount: pageCount,
    copy: copy,
    copies: copies,
    phase: phase ?? this.phase,
    confirmed: confirmed ?? this.confirmed,
    pageLines: pageLines,
  );

  /// Share of the data handed to the printer — not how much is on paper; see the job's print estimate.
  double get fraction => totalBytes == 0 ? 0 : (sentBytes / totalBytes).clamp(0, 1);

  /// 0-based position of the current page in the whole job (all copies).
  int get sequence => (copy - 1) * pageCount + (page - 1);

  int get totalLines => pageLines.fold(0, (a, b) => a + b) * copies;

  /// Dot-lines of all pages before position [sequence] in the job.
  int linesBefore(int sequence) {
    if (pageLines.isEmpty) return 0;
    var lines = 0;
    for (var i = 0; i < sequence; i++) {
      lines += pageLines[i % pageLines.length];
    }
    return lines;
  }
}
