import 'package:flutter/material.dart';

import 'vio_canvas_theme.dart';
import 'vio_colors.dart';
import 'vio_spacing.dart';
import 'vio_typography.dart';

/// Vio Theme - Blue Dark Mode Design System
class VioTheme {
  VioTheme._();

  // ---------------------------------------------------------------------------
  // Dynamic seed-based theme (M3 ColorScheme.fromSeed)
  // ---------------------------------------------------------------------------

  /// Build a [ThemeData] driven by [seedColor] using Material 3's
  /// [ColorScheme.fromSeed].
  ///
  /// [mode] controls brightness; defaults to [ThemeMode.dark] to match the
  /// Vio design tool's default appearance.
  ///
  /// Using [VioColors.primary] as the seed reproduces a palette very close to
  /// the original fixed blue theme.
  ///
  /// All widget component themes remain consistent with [darkTheme]; only the
  /// [ColorScheme] itself is generated from the seed.
  static ThemeData fromSeed(
    Color seedColor, {
    ThemeMode mode = ThemeMode.dark,
  }) {
    final brightness = mode == ThemeMode.light
        ? Brightness.light
        : Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    final primary = colorScheme.primary;
    final onPrimary = colorScheme.onPrimary;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      extensions: [VioCanvasTheme.fromPrimary(primary, brightness: brightness)],

      // In dark mode we keep the fixed Vio dark surfaces so the design tool
      // chrome always feels dark regardless of the chosen seed color.
      // In light mode we defer to the seed-derived colorScheme background.
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? VioColors.background
          : colorScheme.surface,

      appBarTheme: AppBarTheme(
        backgroundColor: brightness == Brightness.dark
            ? VioColors.surface
            : colorScheme.surfaceContainerLow,
        foregroundColor: brightness == Brightness.dark
            ? VioColors.textPrimary
            : colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: VioTypography.titleLarge,
        toolbarHeight: VioSpacing.toolbarHeight,
      ),

      cardTheme: CardThemeData(
        color: VioColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
          side: const BorderSide(color: VioColors.border),
        ),
        margin: EdgeInsets.zero,
      ),

      dividerTheme: const DividerThemeData(
        color: VioColors.border,
        thickness: 1,
        space: 1,
      ),

      iconTheme: const IconThemeData(
        color: VioColors.textSecondary,
        size: VioSpacing.iconMd,
      ),

      textTheme: TextTheme(
        displayLarge: VioTypography.displayLarge,
        displayMedium: VioTypography.displayMedium,
        displaySmall: VioTypography.displaySmall,
        headlineLarge: VioTypography.headlineLarge,
        headlineMedium: VioTypography.headlineMedium,
        headlineSmall: VioTypography.headlineSmall,
        titleLarge: VioTypography.titleLarge,
        titleMedium: VioTypography.titleMedium,
        titleSmall: VioTypography.titleSmall,
        bodyLarge: VioTypography.bodyLarge,
        bodyMedium: VioTypography.bodyMedium,
        bodySmall: VioTypography.bodySmall,
        labelLarge: VioTypography.labelLarge,
        labelMedium: VioTypography.labelMedium,
        labelSmall: VioTypography.labelSmall,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: VioSpacing.inputPaddingH,
          vertical: VioSpacing.inputPaddingV,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
          borderSide: const BorderSide(color: VioColors.error),
        ),
        hintStyle: VioTypography.bodyMedium.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        labelStyle: VioTypography.labelMedium,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: VioSpacing.buttonPaddingH,
            vertical: VioSpacing.buttonPaddingV,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
          ),
          textStyle: VioTypography.button,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(
            horizontal: VioSpacing.buttonPaddingH,
            vertical: VioSpacing.buttonPaddingV,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
          ),
          textStyle: VioTypography.button,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: VioColors.textPrimary,
          side: const BorderSide(color: VioColors.border),
          padding: const EdgeInsets.symmetric(
            horizontal: VioSpacing.buttonPaddingH,
            vertical: VioSpacing.buttonPaddingV,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
          ),
          textStyle: VioTypography.button,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: VioColors.textSecondary,
          hoverColor: VioColors.hoverOverlay,
          highlightColor: VioColors.pressedOverlay,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
          ),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: VioColors.surfaceHigh,
          borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
          border: Border.all(color: VioColors.border),
        ),
        textStyle: VioTypography.caption.copyWith(color: VioColors.textPrimary),
        padding: const EdgeInsets.symmetric(
          horizontal: VioSpacing.sm,
          vertical: VioSpacing.xs,
        ),
      ),

      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          final alpha = states.contains(WidgetState.hovered) ? 0.6 : 0.35;
          return primary.withValues(alpha: alpha);
        }),
        trackColor: WidgetStateProperty.all(Colors.transparent),
        radius: const Radius.circular(VioSpacing.radiusSm),
        thickness: WidgetStateProperty.all(6),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: VioColors.surfaceHigh,
        thumbColor: primary,
        overlayColor: primary.withValues(alpha: 0.3),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(onPrimary),
        side: const BorderSide(color: VioColors.border, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return VioColors.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withValues(alpha: 0.3);
          }
          return VioColors.surfaceHigh;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surfaceContainer,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        textStyle: VioTypography.bodyMedium.copyWith(
          color: colorScheme.onSurface,
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final base = VioTypography.bodyMedium.copyWith(
            color: colorScheme.onSurface,
          );
          if (states.contains(WidgetState.disabled)) {
            return base.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.38),
            );
          }
          return base;
        }),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: VioColors.surface,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusLg),
          side: const BorderSide(color: VioColors.border),
        ),
        titleTextStyle: VioTypography.headlineMedium,
        contentTextStyle: VioTypography.bodyMedium,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: VioColors.surface,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(VioSpacing.radiusLg),
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: VioColors.surfaceHigh,
        contentTextStyle: VioTypography.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Fixed dark theme (backward compatible)
  // ---------------------------------------------------------------------------

  /// The original fixed-palette dark theme.
  ///
  /// Preserved for backward compatibility. New code should prefer [fromSeed]
  /// so that the application UI tracks the user's chosen seed color.
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      extensions: [VioCanvasTheme.fromPrimary(VioColors.primary)],

      // Colors
      colorScheme: const ColorScheme.dark(
        primary: VioColors.primary,
        onPrimary: VioColors.textPrimary,
        primaryContainer: VioColors.primaryDark,
        onPrimaryContainer: VioColors.textPrimary,
        secondary: VioColors.primaryLight,
        onSecondary: VioColors.background,
        secondaryContainer: VioColors.surfaceElevated,
        onSecondaryContainer: VioColors.textPrimary,
        tertiary: VioColors.info,
        onTertiary: VioColors.textPrimary,
        error: VioColors.error,
        onError: VioColors.textPrimary,
        surface: VioColors.surface,
        onSurface: VioColors.textPrimary,
        surfaceContainerHighest: VioColors.surfaceHigh,
        onSurfaceVariant: VioColors.textSecondary,
        outline: VioColors.border,
        outlineVariant: VioColors.borderSubtle,
        shadow: Colors.black,
        scrim: Colors.black54,
        inverseSurface: VioColors.textPrimary,
        onInverseSurface: VioColors.background,
        inversePrimary: VioColors.primaryDark,
      ),

      // Scaffold
      scaffoldBackgroundColor: VioColors.background,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: VioColors.surface,
        foregroundColor: VioColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: VioTypography.titleLarge,
        toolbarHeight: VioSpacing.toolbarHeight,
      ),

      // Card
      cardTheme: CardThemeData(
        color: VioColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
          side: const BorderSide(color: VioColors.border),
        ),
        margin: EdgeInsets.zero,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: VioColors.border,
        thickness: 1,
        space: 1,
      ),

      // Icon
      iconTheme: const IconThemeData(
        color: VioColors.textSecondary,
        size: VioSpacing.iconMd,
      ),

      // Text - Using Google Fonts Inter
      textTheme: TextTheme(
        displayLarge: VioTypography.displayLarge,
        displayMedium: VioTypography.displayMedium,
        displaySmall: VioTypography.displaySmall,
        headlineLarge: VioTypography.headlineLarge,
        headlineMedium: VioTypography.headlineMedium,
        headlineSmall: VioTypography.headlineSmall,
        titleLarge: VioTypography.titleLarge,
        titleMedium: VioTypography.titleMedium,
        titleSmall: VioTypography.titleSmall,
        bodyLarge: VioTypography.bodyLarge,
        bodyMedium: VioTypography.bodyMedium,
        bodySmall: VioTypography.bodySmall,
        labelLarge: VioTypography.labelLarge,
        labelMedium: VioTypography.labelMedium,
        labelSmall: VioTypography.labelSmall,
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VioColors.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: VioSpacing.inputPaddingH,
          vertical: VioSpacing.inputPaddingV,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
          borderSide: const BorderSide(color: VioColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
          borderSide: const BorderSide(color: VioColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
          borderSide: const BorderSide(color: VioColors.borderFocus, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
          borderSide: const BorderSide(color: VioColors.error),
        ),
        hintStyle: VioTypography.bodyMedium.copyWith(
          color: VioColors.textTertiary,
        ),
        labelStyle: VioTypography.labelMedium,
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: VioColors.primary,
          foregroundColor: VioColors.background,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: VioSpacing.buttonPaddingH,
            vertical: VioSpacing.buttonPaddingV,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
          ),
          textStyle: VioTypography.button,
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: VioColors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: VioSpacing.buttonPaddingH,
            vertical: VioSpacing.buttonPaddingV,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
          ),
          textStyle: VioTypography.button,
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: VioColors.textPrimary,
          side: const BorderSide(color: VioColors.border),
          padding: const EdgeInsets.symmetric(
            horizontal: VioSpacing.buttonPaddingH,
            vertical: VioSpacing.buttonPaddingV,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
          ),
          textStyle: VioTypography.button,
        ),
      ),

      // Icon Button
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: VioColors.textSecondary,
          hoverColor: VioColors.hoverOverlay,
          highlightColor: VioColors.pressedOverlay,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
          ),
        ),
      ),

      // Tooltip
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: VioColors.surfaceHigh,
          borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
          border: Border.all(color: VioColors.border),
        ),
        textStyle: VioTypography.caption.copyWith(color: VioColors.textPrimary),
        padding: const EdgeInsets.symmetric(
          horizontal: VioSpacing.sm,
          vertical: VioSpacing.xs,
        ),
      ),

      // Scrollbar
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          final alpha = states.contains(WidgetState.hovered) ? 0.6 : 0.35;
          return VioColors.primary.withValues(alpha: alpha);
        }),
        trackColor: WidgetStateProperty.all(Colors.transparent),
        radius: const Radius.circular(VioSpacing.radiusSm),
        thickness: WidgetStateProperty.all(6),
      ),

      // Slider
      sliderTheme: const SliderThemeData(
        activeTrackColor: VioColors.primary,
        inactiveTrackColor: VioColors.surfaceHigh,
        thumbColor: VioColors.primary,
        overlayColor: VioColors.primary30,
        trackHeight: 4,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
      ),

      // Checkbox
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return VioColors.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(VioColors.background),
        side: const BorderSide(color: VioColors.border, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
        ),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return VioColors.primary;
          }
          return VioColors.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return VioColors.primary30;
          }
          return VioColors.surfaceHigh;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // Popup Menu
      popupMenuTheme: PopupMenuThemeData(
        color: VioColors.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
          side: const BorderSide(color: VioColors.border),
        ),
        textStyle: VioTypography.bodyMedium,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: VioColors.surface,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusLg),
          side: const BorderSide(color: VioColors.border),
        ),
        titleTextStyle: VioTypography.headlineMedium,
        contentTextStyle: VioTypography.bodyMedium,
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: VioColors.surface,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(VioSpacing.radiusLg),
          ),
        ),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: VioColors.surfaceHigh,
        contentTextStyle: VioTypography.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
