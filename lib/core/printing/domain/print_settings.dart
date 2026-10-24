enum Dither {
  off('Off'),
  floyd('Floyd'),
  atkinson('Atkinson');

  final String label;
  const Dither(this.label);
}

enum ScaleMode {
  fitWidth('Fit width'),
  original('Original');

  final String label;
  const ScaleMode(this.label);
}

enum PageSelection {
  all('All'),
  custom('Pages');

  final String label;
  const PageSelection(this.label);
}

/// Everything needed to reproduce a print exactly; stored with each history entry.
final class PrintSettings {
  final Dither dither;
  final ScaleMode scale;

  /// Clockwise quarter turns (0–3).
  final int rotation;

  /// Density level 0–2, sent before the job.
  final int density;
  final int copies;
  final PageSelection pages;

  /// 1-based page list used for [PageSelection.custom], e.g. `1-3, 5`.
  final String pageSpec;

  /// 0-based page shown in the preview.
  final int currentPage;

  /// Blank paper fed after each page on roll paper, in dots.
  final int feedDots;

  const PrintSettings({
    this.dither = Dither.floyd,
    this.scale = ScaleMode.fitWidth,
    this.rotation = 0,
    this.density = 1,
    this.copies = 1,
    this.pages = PageSelection.all,
    this.pageSpec = '1',
    this.currentPage = 0,
    this.feedDots = 80,
  });

  /// 0-based pages to print, in document order. Empty if [pageSpec] names no valid page.
  List<int> pageIndices(int pageCount) => switch (pages) {
    PageSelection.all => [for (var i = 0; i < pageCount; i++) i],
    PageSelection.custom => parsePageSpec(pageSpec, pageCount),
  };

  /// Parses "1-3, 5, 8-" style lists. Out-of-range pages and garbage are ignored.
  static List<int> parsePageSpec(String spec, int pageCount) {
    final pages = <int>{};
    for (final part in spec.split(RegExp(r'[,;\s]+'))) {
      final match = RegExp(r'^(\d*)(-(\d*))?$').firstMatch(part.trim());
      if (match == null || part.trim().isEmpty) continue;
      final from = int.tryParse(match.group(1)!) ?? 1;
      final to = match.group(2) == null ? from : (int.tryParse(match.group(3)!) ?? pageCount);
      for (var p = from; p <= to && p <= pageCount; p++) {
        if (p >= 1) pages.add(p - 1);
      }
    }
    return pages.toList()..sort();
  }

  PrintSettings copyWith({
    Dither? dither,
    ScaleMode? scale,
    int? rotation,
    int? density,
    int? copies,
    PageSelection? pages,
    String? pageSpec,
    int? currentPage,
  }) => PrintSettings(
    dither: dither ?? this.dither,
    scale: scale ?? this.scale,
    rotation: rotation ?? this.rotation,
    density: density ?? this.density,
    copies: copies ?? this.copies,
    pages: pages ?? this.pages,
    pageSpec: pageSpec ?? this.pageSpec,
    currentPage: currentPage ?? this.currentPage,
    feedDots: feedDots,
  );

  Map<String, dynamic> toJson() => {
    'dither': dither.name,
    'scale': scale.name,
    'rotation': rotation,
    'density': density,
    'copies': copies,
    'pages': pages.name,
    'pageSpec': pageSpec,
    'currentPage': currentPage,
    'feedDots': feedDots,
  };

  static PrintSettings fromJson(Map<String, dynamic> json) {
    // Entries from the first version stored "current" / "range" selections.
    final legacy = switch (json['pages']) {
      'current' => '${(json['currentPage'] as int? ?? 0) + 1}',
      'range' => '${(json['rangeStart'] as int? ?? 0) + 1}-${(json['rangeEnd'] as int? ?? 0) + 1}',
      _ => null,
    };
    return PrintSettings(
      dither: Dither.values.asNameMap()[json['dither']] ?? Dither.floyd,
      scale: ScaleMode.values.asNameMap()[json['scale']] ?? ScaleMode.fitWidth,
      rotation: json['rotation'] as int? ?? 0,
      density: json['density'] as int? ?? 1,
      copies: json['copies'] as int? ?? 1,
      pages: legacy != null ? PageSelection.custom : (PageSelection.values.asNameMap()[json['pages']] ?? PageSelection.all),
      pageSpec: legacy ?? json['pageSpec'] as String? ?? '1',
      currentPage: json['currentPage'] as int? ?? 0,
      feedDots: json['feedDots'] as int? ?? 80,
    );
  }
}
