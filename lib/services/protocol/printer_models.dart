/// Capabilities of a printer family, derived from its Bluetooth name.
final class PrinterModel {
  /// Printable width in dots.
  final int widthDots;
  final int dpi;

  /// The official app sends these models compressed raster data (`1F 00 …`) produced by a native
  /// library that is not available to us. We still send `GS v 0`, which may or may not be accepted.
  final bool prefersCompressedRaster;

  const PrinterModel({required this.widthDots, required this.dpi, this.prefersCompressedRaster = false});

  static const fallback = PrinterModel(widthDots: 384, dpi: 203);

  /// Bluetooth name prefixes that belong to PeriPage printers.
  static const knownPrefixes = ['PeriPage', 'PPG_', 'SQAI_PP_', 'PRT1_'];

  static bool isPeriPage(String name) => knownPrefixes.any(name.startsWith);

  // Names the official app routes through the compressed raster path (y0.h#n).
  static const _compressedExact = {
    'PeriPage_A9', 'PeriPage_A9+', 'PeriPage_A9Pro+', 'PeriPage_A9s', 'PeriPage_Q9s', 'PeriPage_A9sMAX', 'PeriPage_A9MAX',
    'PeriPage_Q9Pro+', 'PeriPage_Q10s', 'PeriPage_A40', 'PeriPage_H2', 'PeriPage_H2+', 'PeriPage_P40', 'PeriPage_P9',
    'SQAI_PP_G10', 'SQAI_PP_G40', 'PeriPage_A3X', 'PeriPage_A3X+', 'PeriPage_A40+', 'PeriPage_A40Pro+',
    'PeriPage_A40Pro', 'PeriPage_Y200', 'PeriPage_Y200+',
  };
  static const _compressedPrefixes = ['PeriPage_A8_', 'PeriPage_A8+', 'PRT1_', 'PPG_P40W', 'PPG_P40'];

  // Width rules taken from y6.f#r0 for roll paper; first match wins.
  static const _widthRules = <(String, int, int)>[
    ('PeriPage_A3_', 576, 304),
    ('PeriPage_Q7Pro', 576, 304),
    ('PeriPage_A3X+', 600, 304),
    ('PPG_P30+', 600, 304),
    ('PeriPage_A3X', 400, 203),
    ('PPG_P30', 400, 203),
    ('PeriPage_A40', 1664, 203),
    ('PeriPage_Y200', 1664, 203),
    ('PPG_A40', 1664, 203),
    ('PPG_P40', 1664, 203),
    ('PeriPage_Q7', 384, 203),
    ('PPG_P20', 384, 203),
    ('PeriPage_A8_', 384, 203),
  ];

  static PrinterModel fromName(String name) {
    final compressed = _compressedExact.contains(name) || _compressedPrefixes.any(name.startsWith);
    for (final (prefix, width, dpi) in _widthRules) {
      if (name.startsWith(prefix)) {
        return PrinterModel(widthDots: width, dpi: dpi, prefersCompressedRaster: compressed);
      }
    }
    final hd = name.contains('_HD') || name.contains('_UHD') || name.contains('+');
    return PrinterModel(widthDots: hd ? 576 : 384, dpi: hd ? 304 : 203, prefersCompressedRaster: compressed);
  }
}
