import 'package:flutter/material.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

/// Ruler constants
class RulerConstants {
  static const double rulerSize = 20.0;
  static const double selectionHighlightOpacity = 0.3;
  static const Color selectionHighlightColor = VioColors.primary;

  /// Minimum spacing between major ruler labels in logical pixels.
  static const double minLabelPixelSpacing = 48.0;

  /// Minimum spacing between major ruler ticks in logical pixels.
  static const double minMajorTickPixelSpacing = 24.0;

  /// Below this, minor ticks are hidden to avoid dense noise at low zoom.
  static const double hideMinorTicksThreshold = 36.0;

  /// Below this, only the midpoint minor tick is rendered.
  static const double midpointMinorTickThreshold = 96.0;

  static int computeLabelSkipFactor(double scaledInterval) {
    if (scaledInterval <= 0) {
      return 1;
    }

    final factor = (minLabelPixelSpacing / scaledInterval).ceil();
    return factor < 1 ? 1 : factor;
  }

  static double adjustMajorTickIntervalForZoom(
    double baseInterval,
    double zoom,
  ) {
    if (baseInterval <= 0 || zoom <= 0) {
      return baseInterval;
    }

    final scaledInterval = baseInterval * zoom;
    if (scaledInterval >= minMajorTickPixelSpacing) {
      return baseInterval;
    }

    final multiplier = (minMajorTickPixelSpacing / scaledInterval).ceil();
    return baseInterval * multiplier;
  }

  static List<double> computeMinorTickFractions(double scaledInterval) {
    if (scaledInterval < hideMinorTicksThreshold) {
      return const [];
    }

    if (scaledInterval < midpointMinorTickThreshold) {
      return const [0.5];
    }

    return const [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9];
  }
}
