/// The user cancelled a print job.
final class PrintCancelledException implements Exception {
  /// Whether the transfer stopped in the middle of a page. The printer then holds half a raster frame and
  /// the connection should be reset so it drops it.
  final bool midPage;

  /// Whether at least one complete page reached the printer.
  final bool pagesSent;

  const PrintCancelledException({required this.midPage, required this.pagesSent});
}
