import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vio_client/src/features/canvas/bloc/canvas_bloc.dart';
import 'package:vio_core/vio_core.dart';

class CanvasTextEditorOverlay extends StatelessWidget {
  const CanvasTextEditorOverlay({
    required this.shapeId,
    required this.controller,
    required this.focusNode,
    required this.canvasState,
    super.key,
  });

  final String shapeId;
  final TextEditingController controller;
  final FocusNode focusNode;
  final CanvasState canvasState;

  @override
  Widget build(BuildContext context) {
    final shape = canvasState.shapes[shapeId];
    if (shape is! TextShape) {
      return const SizedBox.shrink();
    }

    final bounds = shape.bounds;
    final anchorCanvas = shape.transformPoint(bounds.topLeft);
    final anchorScreen = canvasState.canvasToScreen(anchorCanvas);

    final canvasWidth = bounds.width <= 1 ? 200.0 : bounds.width;
    final canvasHeight = bounds.height <= 1 ? 24.0 : bounds.height;

    final screenWidth = canvasWidth * canvasState.zoom;
    final screenHeight = canvasHeight * canvasState.zoom;

    final fill = shape.fills.isNotEmpty ? shape.fills.first : null;
    final color = fill != null
        ? Color(fill.color).withValues(alpha: fill.opacity)
        : const Color(0xFFE6EDF3);

    FontWeight? fontWeight;
    final weightValue = shape.fontWeight;
    if (weightValue != null) {
      fontWeight = FontWeight.values.firstWhere(
        (w) => w.value == weightValue,
        orElse: () => FontWeight.w400,
      );
    }

    final scaledFontSize = shape.fontSize * canvasState.zoom;
    final scaledLetterSpacing = shape.letterSpacingPercent == 0
        ? null
        : scaledFontSize * (shape.letterSpacingPercent / 100.0);

    final baseStyle = TextStyle(
      color: color,
      fontSize: scaledFontSize,
      fontWeight: fontWeight,
      height: shape.lineHeight,
      letterSpacing: scaledLetterSpacing,
    );

    TextStyle resolveFontStyle() {
      final family = shape.fontFamily;
      if (family == null || family.isEmpty) {
        return baseStyle;
      }
      try {
        return GoogleFonts.getFont(family, textStyle: baseStyle);
      } catch (_) {
        return baseStyle.copyWith(fontFamily: family);
      }
    }

    return Positioned(
      left: anchorScreen.dx,
      top: anchorScreen.dy,
      child: SizedBox(
        width: screenWidth,
        height: screenHeight,
        child: EditableText(
          controller: controller,
          focusNode: focusNode,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textAlign: shape.textAlign,
          textDirection: TextDirection.ltr,
          style: resolveFontStyle(),
          cursorColor: Theme.of(context).colorScheme.primary,
          backgroundCursorColor: Theme.of(context).colorScheme.surface,
          selectionColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}
