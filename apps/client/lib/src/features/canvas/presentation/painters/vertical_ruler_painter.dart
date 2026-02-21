import 'package:flutter/material.dart';
import 'package:vio_client/src/features/canvas/presentation/painters/horizontal_ruler_painter.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

/// Vertical ruler painter with selection highlight
class VerticalRulerPainter extends CustomPainter {
  VerticalRulerPainter({
    required this.offset,
    required this.zoom,
    this.selectionRect,
    this.rulerOffset = RulerConstants.rulerSize,
  });

  final double offset;
  final double zoom;
  final Rect? selectionRect;

  /// Offset to account for ruler positioning (vertical ruler starts after horizontal ruler)
  final double rulerOffset;

  @override
  void paint(Canvas canvas, Size size) {
    // The ruler widget is shifted by [rulerOffset] pixels (because the
    // horizontal ruler occupies the top gutter). Adjust the viewport offset so
    // tick values line up with the actual canvas origin.
    final effectiveOffset = offset - rulerOffset;

    final paint = Paint()
      ..color = VioColors.surface2
      ..style = PaintingStyle.fill;

    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Draw selection highlight on ruler
    if (selectionRect != null) {
      _drawSelectionHighlight(canvas, size);
    }

    // Tick marks
    final tickPaint = Paint()
      ..color = VioColors.textTertiary
      ..strokeWidth = 1;

    // Calculate tick interval based on zoom
    double interval = 100;
    if (zoom < 0.25) {
      interval = 400;
    } else if (zoom < 0.5) {
      interval = 200;
    } else if (zoom > 2) {
      interval = 50;
    } else if (zoom > 4) {
      interval = 25;
    }

    final scaledInterval = interval * zoom;
    final startValue = (-effectiveOffset / zoom / interval).floor() * interval;
    final startY = startValue * zoom + effectiveOffset;

    for (double y = startY; y < size.height; y += scaledInterval) {
      final value = ((y - effectiveOffset) / zoom).round();

      // Major tick
      canvas.drawLine(
        Offset(size.width - 8, y),
        Offset(size.width, y),
        tickPaint,
      );

      // Label (rotated)
      canvas.save();
      canvas.translate(3, y + 2);
      canvas.rotate(-1.5708); // -90 degrees

      final textPainter = TextPainter(
        text: TextSpan(
          text: value.toString(),
          style: VioTypography.caption.copyWith(
            color: VioColors.textTertiary,
            fontSize: 9,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();

      // Minor ticks
      for (int i = 1; i < 10; i++) {
        final minorY = y + (scaledInterval / 10) * i;
        if (minorY < size.height) {
          canvas.drawLine(
            Offset(size.width - (i == 5 ? 5 : 3), minorY),
            Offset(size.width, minorY),
            tickPaint,
          );
        }
      }
    }
  }

  void _drawSelectionHighlight(Canvas canvas, Size size) {
    if (selectionRect == null) return;

    final effectiveOffset = offset - rulerOffset;

    // Convert selection bounds to screen coordinates
    // Subtract rulerOffset because the canvas content area starts after the horizontal ruler
    final topScreen = selectionRect!.top * zoom + effectiveOffset;
    final bottomScreen = selectionRect!.bottom * zoom + effectiveOffset;

    // Clamp to visible area
    final visibleTop = topScreen.clamp(0.0, size.height);
    final visibleBottom = bottomScreen.clamp(0.0, size.height);

    if (visibleBottom <= visibleTop) return;

    // Draw highlight rectangle
    final highlightPaint = Paint()
      ..color = RulerConstants.selectionHighlightColor
          .withValues(alpha: RulerConstants.selectionHighlightOpacity)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, visibleTop, size.width, visibleBottom - visibleTop),
      highlightPaint,
    );

    // Draw edge indicators with coordinate labels
    final edgePaint = Paint()
      ..color = RulerConstants.selectionHighlightColor
      ..strokeWidth = 1;

    // Top edge indicator
    if (topScreen >= 0 && topScreen <= size.height) {
      canvas.drawLine(
        Offset(0, topScreen),
        Offset(size.width, topScreen),
        edgePaint,
      );
      _drawCoordinateLabel(
        canvas,
        size,
        selectionRect!.top.round().toString(),
        topScreen,
        isTop: true,
      );
    }

    // Bottom edge indicator
    if (bottomScreen >= 0 && bottomScreen <= size.height) {
      canvas.drawLine(
        Offset(0, bottomScreen),
        Offset(size.width, bottomScreen),
        edgePaint,
      );
      _drawCoordinateLabel(
        canvas,
        size,
        selectionRect!.bottom.round().toString(),
        bottomScreen,
        isTop: false,
      );
    }
  }

  void _drawCoordinateLabel(
    Canvas canvas,
    Size size,
    String text,
    double y, {
    required bool isTop,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: VioTypography.caption.copyWith(
          color: RulerConstants.selectionHighlightColor,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Position label - rotated for vertical ruler
    canvas.save();

    final yOffset = isTop ? y - textPainter.width - 4 : y + 4;

    canvas.translate(size.width / 2, yOffset);
    canvas.rotate(-1.5708); // -90 degrees

    // Background for readability
    final bgPaint = Paint()
      ..color = VioColors.surface2
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(
        -1,
        -textPainter.height / 2 - 1,
        textPainter.width + 2,
        textPainter.height + 2,
      ),
      bgPaint,
    );

    textPainter.paint(canvas, Offset(0, -textPainter.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(VerticalRulerPainter oldDelegate) {
    return offset != oldDelegate.offset ||
        zoom != oldDelegate.zoom ||
        selectionRect != oldDelegate.selectionRect;
  }
}
