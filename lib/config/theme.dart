import 'package:flutter/material.dart';
import 'package:peripage_app/config/constants.dart';

/// Colors of the glass design that Material's ColorScheme has no slot for.
@immutable
final class GlassColors extends ThemeExtension<GlassColors> {
  final Color background;
  final Color ink;
  final Color muted;
  final Color line;
  final Color glass;
  final Color glassStrong;
  final Color glassEdge;
  final Color accent;
  final Color onAccent;
  final List<Color> blobs;

  const GlassColors({
    required this.background,
    required this.ink,
    required this.muted,
    required this.line,
    required this.glass,
    required this.glassStrong,
    required this.glassEdge,
    required this.accent,
    required this.onAccent,
    required this.blobs,
  });

  static const light = GlassColors(
    background: AppColors.lightBg,
    ink: AppColors.lightInk,
    muted: AppColors.lightMuted,
    line: AppColors.lightLine,
    glass: AppColors.lightGlass,
    glassStrong: AppColors.lightGlassStrong,
    glassEdge: AppColors.lightGlassEdge,
    accent: AppColors.accent,
    onAccent: AppColors.onAccent,
    blobs: AppColors.lightBlobs,
  );

  static const dark = GlassColors(
    background: AppColors.darkBg,
    ink: AppColors.darkInk,
    muted: AppColors.darkMuted,
    line: AppColors.darkLine,
    glass: AppColors.darkGlass,
    glassStrong: AppColors.darkGlassStrong,
    glassEdge: AppColors.darkGlassEdge,
    accent: AppColors.accentDark,
    onAccent: AppColors.onAccentDark,
    blobs: AppColors.darkBlobs,
  );

  @override
  GlassColors copyWith() => this;

  @override
  GlassColors lerp(covariant GlassColors? other, double t) => t < .5 || other == null ? this : other;
}

extension GlassThemeContext on BuildContext {
  GlassColors get glass => Theme.of(this).extension<GlassColors>()!;
}

final class AppTheme {
  final Brightness _brightness;
  final GlassColors _colors;

  AppTheme._(this._brightness) : _colors = _brightness == Brightness.light ? GlassColors.light : GlassColors.dark;

  static ThemeData get light => AppTheme._(Brightness.light)._buildTheme();
  static ThemeData get dark => AppTheme._(Brightness.dark)._buildTheme();

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: _brightness,
      scaffoldBackgroundColor: _colors.background,
      colorScheme: _buildColorScheme(),
      textTheme: _buildTextTheme(),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: _colors.line,
      dividerColor: _colors.line,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _colors.ink,
        contentTextStyle: TextStyle(color: _colors.background, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      extensions: [_colors],
    );
  }

  ColorScheme _buildColorScheme() {
    return ColorScheme(
      brightness: _brightness,
      primary: _colors.accent,
      onPrimary: _colors.onAccent,
      secondary: _colors.ink,
      onSecondary: _colors.background,
      error: _colors.accent,
      onError: _colors.onAccent,
      surface: _colors.background,
      onSurface: _colors.ink,
    );
  }

  TextTheme _buildTextTheme() {
    return TextTheme(
      headlineMedium: TextStyle(color: _colors.ink, fontSize: 27, fontWeight: FontWeight.w600, letterSpacing: -.7),
      titleMedium: TextStyle(color: _colors.ink, fontSize: 15, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: _colors.ink, fontSize: 15),
      bodyMedium: TextStyle(color: _colors.ink, fontSize: 14, height: 1.45),
      bodySmall: TextStyle(color: _colors.muted, fontSize: 12),
      labelSmall: TextStyle(color: _colors.muted, fontSize: 11, letterSpacing: .5, fontWeight: FontWeight.w500),
    );
  }
}
