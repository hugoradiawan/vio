import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'vio_colors.dart';

/// Vio Typography System
class VioTypography {
  VioTypography._();

  /// Get Inter text style with given properties
  static TextStyle _inter({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    double letterSpacing = 0,
    double height = 1.5,
    Color color = VioColors.textPrimary,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
    );
  }

  /// Get JetBrains Mono text style for code/mono
  static TextStyle _mono({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w400,
    double letterSpacing = 0,
    double height = 1.5,
    Color color = VioColors.textSecondary,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
    );
  }

  // ============== Display Styles ==============
  static TextStyle get displayLarge => _inter(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static TextStyle get displayMedium => _inter(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static TextStyle get displaySmall => _inter(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    height: 1.25,
  );

  // ============== Headline Styles ==============
  static TextStyle get headlineLarge => _inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    height: 1.3,
  );

  static TextStyle get headlineMedium => _inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  static TextStyle get headlineSmall => _inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.35,
  );

  // ============== Title Styles ==============
  static TextStyle get titleLarge => _inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.4,
  );

  static TextStyle get titleMedium => _inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.4,
  );

  static TextStyle get titleSmall => _inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.4,
  );

  // ============== Body Styles ==============
  static TextStyle get bodyLarge => _inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.5,
  );

  static TextStyle get bodyMedium => _inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.5,
  );

  static TextStyle get bodySmall => _inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    height: 1.5,
    color: VioColors.textSecondary,
  );

  // ============== Label Styles ==============
  static TextStyle get labelLarge => _inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.4,
  );

  static TextStyle get labelMedium => _inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.25,
    height: 1.4,
  );

  static TextStyle get labelSmall => _inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    height: 1.4,
    color: VioColors.textSecondary,
  );

  // ============== Special Styles ==============
  /// Monospace style for coordinates, code, etc.
  static TextStyle get mono => _mono(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
  );

  /// Monospace small
  static TextStyle get monoSmall => _mono(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.4,
  );

  /// Button text
  static TextStyle get button => _inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.2,
  );

  /// Caption/tooltip
  static TextStyle get caption => _inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    height: 1.3,
    color: VioColors.textTertiary,
  );

  // ============== Legacy Aliases ==============
  /// Alias for bodyMedium (backwards compatibility)
  static TextStyle get body2 => bodyMedium;

  /// Alias for titleSmall (backwards compatibility)
  static TextStyle get subtitle2 => titleSmall;
}
