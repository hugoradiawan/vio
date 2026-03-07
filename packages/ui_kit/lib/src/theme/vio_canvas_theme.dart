import 'package:flutter/material.dart';

import 'vio_colors.dart';

/// Canvas-specific theme extension.
///
/// Holds design-tool chrome colors (grid lines, selection handles, guides,
/// snap indicators) that are decoupled from the application UI chrome.
/// The canvas background is derived from the chosen seed color: same hue as the
/// primary color but darkened to near-black with very low saturation, so the
/// design surface always feels dark while subtly reflecting the seed accent.
///
/// Consumers reach this via [VioCanvasTheme.of]:
/// ```dart
/// final canvasTheme = VioCanvasTheme.of(context);
/// paint.color = canvasTheme.selectionColor;
/// ```
///
/// Note: [CustomPainter.paint] has no [BuildContext]. Resolve the extension
/// in the parent widget and pass the relevant colors into the painter
/// constructor.
class VioCanvasTheme extends ThemeExtension<VioCanvasTheme> {
  const VioCanvasTheme({
    required this.canvasBackground,
    required this.gridLines,
    required this.gridLinesFine,
    required this.selectionColor,
    required this.selectionFill,
    required this.snapColor,
    required this.guidesColor,
  });

  final Color canvasBackground;
  final Color gridLines;
  final Color gridLinesFine;

  /// Selection handles / bounding-box stroke — tracks [ColorScheme.primary].
  final Color selectionColor;

  /// Selection bounding-box fill (semi-transparent).
  final Color selectionFill;

  final Color snapColor;
  final Color guidesColor;

  // ---------------------------------------------------------------------------
  // Convenience factory
  // ---------------------------------------------------------------------------

  /// Build a canvas theme where [selectionColor] and [canvasBackground] are
  /// derived from [primary].
  ///
  /// In dark mode the canvas background is pushed to ~5 % lightness (near-
  /// black with a subtle hue tint). In light mode it is pushed to ~95 %
  /// lightness (near-white with the same subtle tint), so the design surface
  /// stays legible in both themes.
  factory VioCanvasTheme.fromPrimary(
    Color primary, {
    Brightness brightness = Brightness.dark,
  }) {
    final hsl = HSLColor.fromColor(primary);
    final isLight = brightness == Brightness.light;
    // Keep the hue, desaturate heavily, and push lightness to near-black (dark)
    // or near-white (light).
    final canvasBg = hsl
        .withSaturation((hsl.saturation * 0.25).clamp(0.0, 0.2))
        .withLightness(isLight ? 0.95 : 0.05)
        .toColor();
    return VioCanvasTheme(
      canvasBackground: canvasBg,
      gridLines: VioColors.gridLines,
      gridLinesFine: VioColors.gridLinesFine,
      selectionColor: primary,
      selectionFill: primary.withValues(alpha: 0.15),
      snapColor: VioColors.snap,
      guidesColor: VioColors.guides,
    );
  }

  // ---------------------------------------------------------------------------
  // Resolution helper
  // ---------------------------------------------------------------------------

  /// Resolve the [VioCanvasTheme] extension from [context].
  ///
  /// Throws an [AssertionError] in debug mode if the extension is absent —
  /// ensure the theme is built with [VioTheme.fromSeed] or that
  /// [VioCanvasTheme] is listed in [ThemeData.extensions].
  static VioCanvasTheme of(BuildContext context) {
    final ext = Theme.of(context).extension<VioCanvasTheme>();
    assert(
      ext != null,
      'VioCanvasTheme extension not found in the current Theme. '
      'Build ThemeData using VioTheme.fromSeed().',
    );
    return ext!;
  }

  // ---------------------------------------------------------------------------
  // ThemeExtension contract
  // ---------------------------------------------------------------------------

  @override
  VioCanvasTheme copyWith({
    Color? canvasBackground,
    Color? gridLines,
    Color? gridLinesFine,
    Color? selectionColor,
    Color? selectionFill,
    Color? snapColor,
    Color? guidesColor,
  }) {
    return VioCanvasTheme(
      canvasBackground: canvasBackground ?? this.canvasBackground,
      gridLines: gridLines ?? this.gridLines,
      gridLinesFine: gridLinesFine ?? this.gridLinesFine,
      selectionColor: selectionColor ?? this.selectionColor,
      selectionFill: selectionFill ?? this.selectionFill,
      snapColor: snapColor ?? this.snapColor,
      guidesColor: guidesColor ?? this.guidesColor,
    );
  }

  @override
  VioCanvasTheme lerp(VioCanvasTheme? other, double t) {
    if (other is! VioCanvasTheme) return this;
    return VioCanvasTheme(
      canvasBackground:
          Color.lerp(canvasBackground, other.canvasBackground, t)!,
      gridLines: Color.lerp(gridLines, other.gridLines, t)!,
      gridLinesFine: Color.lerp(gridLinesFine, other.gridLinesFine, t)!,
      selectionColor: Color.lerp(selectionColor, other.selectionColor, t)!,
      selectionFill: Color.lerp(selectionFill, other.selectionFill, t)!,
      snapColor: Color.lerp(snapColor, other.snapColor, t)!,
      guidesColor: Color.lerp(guidesColor, other.guidesColor, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VioCanvasTheme &&
        other.canvasBackground == canvasBackground &&
        other.gridLines == gridLines &&
        other.gridLinesFine == gridLinesFine &&
        other.selectionColor == selectionColor &&
        other.selectionFill == selectionFill &&
        other.snapColor == snapColor &&
        other.guidesColor == guidesColor;
  }

  @override
  int get hashCode => Object.hash(
        canvasBackground,
        gridLines,
        gridLinesFine,
        selectionColor,
        selectionFill,
        snapColor,
        guidesColor,
      );
}
