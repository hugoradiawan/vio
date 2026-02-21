import 'package:flutter/material.dart';
import 'package:vio_client/src/features/canvas/const/ruler.const.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

/// Horizontal ruler painter with selection highlight
class HorizontalRulerPainter extends CustomPainter {
  HorizontalRulerPainter({
    required this.offset,
    required this.zoom,
    this.selectionRect,
    this.rulerOffset = RulerConstants.rulerSize,
  });

  final double offset;
  final double zoom;
  final Rect? selectionRect;

  /// Offset to account for ruler positioning (horizontal ruler starts after vertical ruler)
  final double rulerOffset;

  @override
  void paint(Canvas canvas, Size size) {
    // The ruler widget is shifted by [rulerOffset] pixels (because the vertical
    // ruler occupies the left gutter). Adjust the viewport offset so tick
    // values line up with the actual canvas origin.
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

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

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
    final startX = startValue * zoom + effectiveOffset;

    for (double x = startX; x < size.width; x += scaledInterval) {
      final value = ((x - effectiveOffset) / zoom).round();

      // Major tick
      canvas.drawLine(
        Offset(x, size.height - 8),
        Offset(x, size.height),
        tickPaint,
      );

      // Label
      textPainter.text = TextSpan(
        text: value.toString(),
        style: VioTypography.caption.copyWith(
          color: VioColors.textTertiary,
          fontSize: 9,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + 2, 2));

      // Minor ticks
      for (int i = 1; i < 10; i++) {
        final minorX = x + (scaledInterval / 10) * i;
        if (minorX < size.width) {
          canvas.drawLine(
            Offset(minorX, size.height - (i == 5 ? 5 : 3)),
            Offset(minorX, size.height),
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
    // Subtract rulerOffset because the canvas content area starts after the vertical ruler
    final leftScreen = selectionRect!.left * zoom + effectiveOffset;
    final rightScreen = selectionRect!.right * zoom + effectiveOffset;

    // Clamp to visible area
    final visibleLeft = leftScreen.clamp(0.0, size.width);
    final visibleRight = rightScreen.clamp(0.0, size.width);

    if (visibleRight <= visibleLeft) return;

    // Draw highlight rectangle
    final highlightPaint = Paint()
      ..color = RulerConstants.selectionHighlightColor
          .withValues(alpha: RulerConstants.selectionHighlightOpacity)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(visibleLeft, 0, visibleRight - visibleLeft, size.height),
      highlightPaint,
    );

    // Draw edge indicators with coordinate labels
    final edgePaint = Paint()
      ..color = RulerConstants.selectionHighlightColor
      ..strokeWidth = 1;

    // Left edge indicator
    if (leftScreen >= 0 && leftScreen <= size.width) {
      canvas.drawLine(
        Offset(leftScreen, 0),
        Offset(leftScreen, size.height),
        edgePaint,
      );
      _drawCoordinateLabel(
        canvas,
        selectionRect!.left.round().toString(),
        Offset(leftScreen, size.height / 2),
        isLeft: true,
      );
    }

    // Right edge indicator
    if (rightScreen >= 0 && rightScreen <= size.width) {
      canvas.drawLine(
        Offset(rightScreen, 0),
        Offset(rightScreen, size.height),
        edgePaint,
      );
      _drawCoordinateLabel(
        canvas,
        selectionRect!.right.round().toString(),
        Offset(rightScreen, size.height / 2),
        isLeft: false,
      );
    }
  }

  void _drawCoordinateLabel(
    Canvas canvas,
    String text,
    Offset position, {
    required bool isLeft,
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

    final xOffset =
        isLeft ? position.dx - textPainter.width - 2 : position.dx + 2;

    // Background for readability
    final bgPaint = Paint()
      ..color = VioColors.surface2
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(
        xOffset - 1,
        position.dy - textPainter.height / 2 - 1,
        textPainter.width + 2,
        textPainter.height + 2,
      ),
      bgPaint,
    );

    textPainter.paint(
      canvas,
      Offset(xOffset, position.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(HorizontalRulerPainter oldDelegate) {
    return offset != oldDelegate.offset ||
        zoom != oldDelegate.zoom ||
        selectionRect != oldDelegate.selectionRect;
  }
}
