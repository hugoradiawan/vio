import 'package:flutter/material.dart';

/// Vio Design System Colors - Blue Dark Mode Theme
///
/// Based on a blue-tinted dark theme optimized for design work
class VioColors {
  VioColors._();

  // ============== Primary Blue Palette ==============
  /// Primary blue - main accent color
  static const Color primary = Color(0xFF4C9AFF);

  /// Primary light variant
  static const Color primaryLight = Color(0xFF7BB8FF);

  /// Primary dark variant
  static const Color primaryDark = Color(0xFF2684FF);

  /// Primary with opacity variants
  static const Color primary50 = Color(0x804C9AFF);
  static const Color primary30 = Color(0x4D4C9AFF);
  static const Color primary10 = Color(0x1A4C9AFF);

  // ============== Surface Colors ==============
  /// Main background - darkest
  static const Color background = Color(0xFF0D1117);

  /// Surface level 1 - panels, cards
  static const Color surface = Color(0xFF161B22);

  /// Surface level 2 - elevated elements
  static const Color surfaceElevated = Color(0xFF21262D);

  /// Surface level 3 - highest elevation
  static const Color surfaceHigh = Color(0xFF30363D);

  /// Canvas background - slightly different for visual distinction
  static const Color canvas = Color(0xFF0A0E13);

  // Legacy aliases for compatibility
  static const Color canvasBackground = canvas;
  static const Color surface1 = surface;
  static const Color surface2 = surfaceElevated;
  static const Color canvasGrid = gridLines;
  static const Color canvasSelection = selection;

  // ============== Border Colors ==============
  /// Default border
  static const Color border = Color(0xFF30363D);

  /// Subtle border
  static const Color borderSubtle = Color(0xFF21262D);

  /// Focused/active border
  static const Color borderFocus = Color(0xFF4C9AFF);

  // ============== Text Colors ==============
  /// Primary text - high emphasis
  static const Color textPrimary = Color(0xFFE6EDF3);

  /// Secondary text - medium emphasis
  static const Color textSecondary = Color(0xFF8B949E);

  /// Tertiary text - low emphasis
  static const Color textTertiary = Color(0xFF6E7681);

  /// Disabled text
  static const Color textDisabled = Color(0xFF484F58);

  /// Link text
  static const Color textLink = Color(0xFF58A6FF);

  // ============== Semantic Colors ==============
  /// Success/green
  static const Color success = Color(0xFF3FB950);
  static const Color successSubtle = Color(0x1A3FB950);

  /// Warning/orange
  static const Color warning = Color(0xFFD29922);
  static const Color warningSubtle = Color(0x1AD29922);

  /// Error/red
  static const Color error = Color(0xFFF85149);
  static const Color errorSubtle = Color(0x1AF85149);

  /// Info/blue
  static const Color info = Color(0xFF58A6FF);
  static const Color infoSubtle = Color(0x1A58A6FF);

  // ============== Canvas/Editor Specific ==============
  /// Grid lines color
  static const Color gridLines = Color(0xFF21262D);

  /// Grid lines (zoomed in, finer grid)
  static const Color gridLinesFine = Color(0xFF161B22);

  /// Selection box
  static const Color selection = Color(0xFF4C9AFF);
  static const Color selectionFill = Color(0x264C9AFF);

  /// Guides and rulers
  static const Color guides = Color(0xFFFF6B6B);

  /// Snapping indicators
  static const Color snap = Color(0xFFFF6B6B);

  /// Shape default fill
  static const Color shapeFillDefault = Color(0xFF30363D);

  /// Shape default stroke
  static const Color shapeStrokeDefault = Color(0xFF8B949E);

  // ============== Interactive States ==============
  /// Hover overlay
  static const Color hoverOverlay = Color(0x0DFFFFFF);

  /// Pressed overlay
  static const Color pressedOverlay = Color(0x1AFFFFFF);

  /// Focus overlay
  static const Color focusOverlay = Color(0x264C9AFF);

  /// Disabled overlay
  static const Color disabledOverlay = Color(0x80000000);

  // ============== Presence/Collaboration ==============
  /// User cursor colors for collaboration
  static const List<Color> userColors = [
    Color(0xFFFF6B6B), // Red
    Color(0xFF4ECDC4), // Teal
    Color(0xFFFFE66D), // Yellow
    Color(0xFF95E1D3), // Mint
    Color(0xFFF38181), // Coral
    Color(0xFFAA96DA), // Purple
    Color(0xFFFCBAD3), // Pink
    Color(0xFFA8D8EA), // Light blue
  ];

  /// Get a user color by index (wraps around)
  static Color getUserColor(int index) {
    return userColors[index % userColors.length];
  }
}
