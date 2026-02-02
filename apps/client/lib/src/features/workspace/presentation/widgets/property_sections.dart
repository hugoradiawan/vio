import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vio_core/vio_core.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../canvas/bloc/canvas_bloc.dart';

/// Section for editing fill properties
class FillSection extends StatelessWidget {
  const FillSection({
    required this.shape,
    super.key,
  });

  final Shape shape;

  @override
  Widget build(BuildContext context) {
    final fills = shape.fills;

    if (fills.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(VioSpacing.sm),
        child: Center(
          child: Text(
            'No fill',
            style: VioTypography.caption.copyWith(
              color: VioColors.textTertiary,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < fills.length; i++)
          _FillItem(
            fill: fills[i],
            index: i,
            shape: shape,
          ),
      ],
    );
  }
}

class _FillItem extends StatelessWidget {
  const _FillItem({
    required this.fill,
    required this.index,
    required this.shape,
  });

  final ShapeFill fill;
  final int index;
  final Shape shape;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(VioSpacing.sm),
      child: Row(
        children: [
          // Visibility toggle
          VioSvgIconButton(
            assetPath: fill.hidden ? VioIcons.eyeOff : VioIcons.eye,
            size: 14,
            buttonSize: 24,
            onPressed: () => _toggleFillVisibility(context),
          ),
          const SizedBox(width: VioSpacing.xs),
          // Color preview
          GestureDetector(
            onTap: () => _showColorPicker(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(fill.color),
                borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
                border: Border.all(color: VioColors.border),
              ),
            ),
          ),
          const SizedBox(width: VioSpacing.sm),
          // Hex value
          Expanded(
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: VioSpacing.sm),
              decoration: BoxDecoration(
                color: VioColors.surfaceElevated,
                borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
                border: Border.all(color: VioColors.border),
              ),
              child: Row(
                children: [
                  Text(
                    '#',
                    style: VioTypography.caption.copyWith(
                      color: VioColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      _colorToHex(fill.color),
                      style: VioTypography.caption.copyWith(
                        color: VioColors.textPrimary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: VioSpacing.xs),
          // Opacity
          SizedBox(
            width: 56,
            child: VioNumericField(
              value: fill.opacity * 100,
              min: 0,
              max: 100,
              onChanged: (value) {
                _updateFillOpacity(context, value / 100);
              },
            ),
          ),
        ],
      ),
    );
  }

  String _colorToHex(int color) {
    return (color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
  }

  Future<void> _showColorPicker(BuildContext context) async {
    final result = await VioColorPickerDialog.show(
      context,
      initialColor: fill.color,
      initialOpacity: fill.opacity,
    );
    if (result != null && context.mounted) {
      final newFills = List<ShapeFill>.from(shape.fills);
      newFills[index] = ShapeFill(
        color: result.color,
        opacity: result.opacity,
        gradient: fill.gradient,
      );
      _updateShape(context, newFills: newFills);
    }
  }

  void _updateFillOpacity(BuildContext context, double opacity) {
    final newFills = List<ShapeFill>.from(shape.fills);
    newFills[index] = fill.copyWith(opacity: opacity);
    _updateShape(context, newFills: newFills);
  }

  void _toggleFillVisibility(BuildContext context) {
    final newFills = List<ShapeFill>.from(shape.fills);
    newFills[index] = fill.copyWith(hidden: !fill.hidden);
    _updateShape(context, newFills: newFills);
  }

  void _updateShape(BuildContext context, {List<ShapeFill>? newFills}) {
    final bloc = context.read<CanvasBloc>();
    final updatedShape = shape.copyWith(fills: newFills);
    bloc.add(ShapeUpdated(updatedShape));
  }
}

/// Section for editing stroke properties
class StrokeSection extends StatelessWidget {
  const StrokeSection({
    required this.shape,
    super.key,
  });

  final Shape shape;

  @override
  Widget build(BuildContext context) {
    final strokes = shape.strokes;

    if (strokes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(VioSpacing.sm),
        child: Center(
          child: Text(
            'No stroke',
            style: VioTypography.caption.copyWith(
              color: VioColors.textTertiary,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < strokes.length; i++)
          _StrokeItem(
            stroke: strokes[i],
            index: i,
            shape: shape,
          ),
      ],
    );
  }
}

class _StrokeItem extends StatelessWidget {
  const _StrokeItem({
    required this.stroke,
    required this.index,
    required this.shape,
  });

  final ShapeStroke stroke;
  final int index;
  final Shape shape;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(VioSpacing.sm),
      child: Column(
        children: [
          Row(
            children: [
              // Visibility toggle
              VioSvgIconButton(
                assetPath: stroke.hidden ? VioIcons.eyeOff : VioIcons.eye,
                size: 14,
                buttonSize: 24,
                onPressed: () => _toggleStrokeVisibility(context),
              ),
              const SizedBox(width: VioSpacing.xs),
              // Color preview
              GestureDetector(
                onTap: () => _showColorPicker(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color(stroke.color),
                    borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
                    border: Border.all(color: VioColors.border),
                  ),
                ),
              ),
              const SizedBox(width: VioSpacing.sm),
              // Hex value
              Expanded(
                child: Container(
                  height: 32,
                  padding:
                      const EdgeInsets.symmetric(horizontal: VioSpacing.sm),
                  decoration: BoxDecoration(
                    color: VioColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
                    border: Border.all(color: VioColors.border),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '#',
                        style: VioTypography.caption.copyWith(
                          color: VioColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          _colorToHex(stroke.color),
                          style: VioTypography.caption.copyWith(
                            color: VioColors.textPrimary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: VioSpacing.xs),
              // Opacity
              SizedBox(
                width: 56,
                child: VioNumericField(
                  value: stroke.opacity * 100,
                  min: 0,
                  max: 100,
                  onChanged: (value) {
                    _updateStrokeOpacity(context, value / 100);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: VioSpacing.sm),
          // Width and alignment
          Row(
            children: [
              const VioIcon(VioIcons.strokeSize, size: 14),
              const SizedBox(width: VioSpacing.sm),
              SizedBox(
                width: 56,
                child: VioNumericField(
                  value: stroke.width,
                  min: 0,
                  max: 100,
                  onChanged: (value) {
                    _updateStrokeWidth(context, value);
                  },
                ),
              ),
              const Spacer(),
              // Alignment dropdown
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: VioSpacing.sm),
                decoration: BoxDecoration(
                  color: VioColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
                  border: Border.all(color: VioColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<StrokeAlignment>(
                    value: stroke.alignment,
                    isDense: true,
                    style: VioTypography.caption.copyWith(
                      color: VioColors.textPrimary,
                    ),
                    dropdownColor: VioColors.surfaceElevated,
                    items: StrokeAlignment.values.map((alignment) {
                      return DropdownMenuItem(
                        value: alignment,
                        child: Text(_alignmentLabel(alignment)),
                      );
                    }).toList(),
                    onChanged: (alignment) {
                      if (alignment != null) {
                        _updateStrokeAlignment(context, alignment);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _colorToHex(int color) {
    return (color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
  }

  String _alignmentLabel(StrokeAlignment alignment) {
    switch (alignment) {
      case StrokeAlignment.center:
        return 'Center';
      case StrokeAlignment.inside:
        return 'Inside';
      case StrokeAlignment.outside:
        return 'Outside';
    }
  }

  Future<void> _showColorPicker(BuildContext context) async {
    final result = await VioColorPickerDialog.show(
      context,
      initialColor: stroke.color,
      initialOpacity: stroke.opacity,
    );
    if (result != null && context.mounted) {
      final newStrokes = List<ShapeStroke>.from(shape.strokes);
      newStrokes[index] = stroke.copyWith(
        color: result.color,
        opacity: result.opacity,
      );
      _updateShape(context, newStrokes: newStrokes);
    }
  }

  void _updateStrokeOpacity(BuildContext context, double opacity) {
    final newStrokes = List<ShapeStroke>.from(shape.strokes);
    newStrokes[index] = stroke.copyWith(opacity: opacity);
    _updateShape(context, newStrokes: newStrokes);
  }

  void _toggleStrokeVisibility(BuildContext context) {
    final newStrokes = List<ShapeStroke>.from(shape.strokes);
    newStrokes[index] = stroke.copyWith(hidden: !stroke.hidden);
    _updateShape(context, newStrokes: newStrokes);
  }

  void _updateStrokeWidth(BuildContext context, double width) {
    final newStrokes = List<ShapeStroke>.from(shape.strokes);
    newStrokes[index] = stroke.copyWith(width: width);
    _updateShape(context, newStrokes: newStrokes);
  }

  void _updateStrokeAlignment(BuildContext context, StrokeAlignment alignment) {
    final newStrokes = List<ShapeStroke>.from(shape.strokes);
    newStrokes[index] = stroke.copyWith(alignment: alignment);
    _updateShape(context, newStrokes: newStrokes);
  }

  void _updateShape(BuildContext context, {List<ShapeStroke>? newStrokes}) {
    final bloc = context.read<CanvasBloc>();
    final updatedShape = shape.copyWith(strokes: newStrokes);
    bloc.add(ShapeUpdated(updatedShape));
  }
}

/// Section for editing shadow properties
class ShadowSection extends StatelessWidget {
  const ShadowSection({
    required this.shape,
    super.key,
  });

  final Shape shape;

  @override
  Widget build(BuildContext context) {
    final shadow = shape.shadow;

    if (shadow == null) {
      return Padding(
        padding: const EdgeInsets.all(VioSpacing.sm),
        child: Center(
          child: Text(
            'No shadow',
            style: VioTypography.caption.copyWith(
              color: VioColors.textTertiary,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(VioSpacing.sm),
      child: Column(
        children: [
          // Color row
          Row(
            children: [
              VioSvgIconButton(
                assetPath: shadow.hidden ? VioIcons.eyeOff : VioIcons.eye,
                size: 14,
                buttonSize: 24,
                onPressed: () {
                  _toggleShadowVisibility(context);
                },
              ),
              const SizedBox(width: VioSpacing.xs),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Color(shadow.color).withValues(alpha: shadow.opacity),
                  borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
                  border: Border.all(color: VioColors.border),
                ),
              ),
              const SizedBox(width: VioSpacing.sm),
              Expanded(
                child: Text(
                  shadow.style == ShadowStyle.dropShadow
                      ? 'Drop Shadow'
                      : 'Inner Shadow',
                  style: VioTypography.caption.copyWith(
                    color: VioColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: VioSpacing.sm),
          // Offset X/Y
          Row(
            children: [
              Expanded(
                child: VioNumericField(
                  label: 'X',
                  value: shadow.offsetX,
                  onChanged: (value) {
                    _updateShadow(context, offsetX: value);
                  },
                ),
              ),
              const SizedBox(width: VioSpacing.sm),
              Expanded(
                child: VioNumericField(
                  label: 'Y',
                  value: shadow.offsetY,
                  onChanged: (value) {
                    _updateShadow(context, offsetY: value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: VioSpacing.sm),
          // Blur and Spread
          Row(
            children: [
              Expanded(
                child: VioNumericField(
                  label: 'Blur',
                  value: shadow.blur,
                  min: 0,
                  onChanged: (value) {
                    _updateShadow(context, blur: value);
                  },
                ),
              ),
              const SizedBox(width: VioSpacing.sm),
              Expanded(
                child: VioNumericField(
                  label: 'Spread',
                  value: shadow.spread,
                  onChanged: (value) {
                    _updateShadow(context, spread: value);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _toggleShadowVisibility(BuildContext context) {
    final shadow = shape.shadow;
    if (shadow == null) return;

    final newShadow = ShapeShadow(
      id: shadow.id,
      style: shadow.style,
      color: shadow.color,
      opacity: shadow.opacity,
      offsetX: shadow.offsetX,
      offsetY: shadow.offsetY,
      blur: shadow.blur,
      spread: shadow.spread,
      hidden: !shadow.hidden,
    );

    final bloc = context.read<CanvasBloc>();
    bloc.add(ShapeUpdated(shape.copyWith(shadow: newShadow)));
  }

  void _updateShadow(
    BuildContext context, {
    double? offsetX,
    double? offsetY,
    double? blur,
    double? spread,
  }) {
    final shadow = shape.shadow;
    if (shadow == null) return;

    final newShadow = ShapeShadow(
      id: shadow.id,
      style: shadow.style,
      color: shadow.color,
      opacity: shadow.opacity,
      offsetX: offsetX ?? shadow.offsetX,
      offsetY: offsetY ?? shadow.offsetY,
      blur: blur ?? shadow.blur,
      spread: spread ?? shadow.spread,
      hidden: shadow.hidden,
    );

    final bloc = context.read<CanvasBloc>();
    bloc.add(ShapeUpdated(shape.copyWith(shadow: newShadow)));
  }
}

// ============================================================================
// Typography (TextShape)
// ============================================================================

class TypographySection extends StatelessWidget {
  const TypographySection({
    required this.shape,
    super.key,
  });

  final TextShape shape;

  static const List<String> _fontFamilyOptions = <String>[
    '',
    'Inter',
    'Roboto',
    'Open Sans',
    'Lato',
    'Montserrat',
    'Poppins',
    'Raleway',
    'Nunito',
    'Merriweather',
    'Playfair Display',
    'Source Sans 3',
    'Ubuntu',
    'Fira Sans',
    'Fira Code',
    'JetBrains Mono',
    // System fonts (fallback via fontFamily)
    'Arial',
    'Courier New',
  ];

  static const List<int> _fontWeightOptions = <int>[
    0, // Default
    100,
    200,
    300,
    400,
    500,
    600,
    700,
    800,
    900,
  ];

  @override
  Widget build(BuildContext context) {
    final isAutoLineHeight = shape.lineHeight == null;
    final fontFamilyValue = shape.fontFamily ?? '';
    final fontWeightValue = shape.fontWeight ?? 0;

    return Padding(
      padding: const EdgeInsets.all(VioSpacing.sm),
      child: Column(
        children: [
          // Font family
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                  label: 'Font',
                  child: _Dropdown<String>(
                    value: _fontFamilyOptions.contains(fontFamilyValue)
                        ? fontFamilyValue
                        : '',
                    items: _fontFamilyOptions,
                    itemLabel: (value) => value.isEmpty ? 'Default' : value,
                    onChanged: (value) {
                      final updated = shape.copyWith(
                        fontFamily: value.isEmpty ? null : value,
                      );
                      _emitUpdated(context, updated, relayoutText: true);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: VioSpacing.sm),

          // Weight + Size
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                  label: 'Weight',
                  child: _Dropdown<int>(
                    value: _fontWeightOptions.contains(fontWeightValue)
                        ? fontWeightValue
                        : 0,
                    items: _fontWeightOptions,
                    itemLabel: (value) =>
                        value == 0 ? 'Default' : value.toString(),
                    onChanged: (value) {
                      final updated = shape.copyWith(
                        fontWeight: value == 0 ? null : value,
                      );
                      _emitUpdated(context, updated, relayoutText: true);
                    },
                  ),
                ),
              ),
              const SizedBox(width: VioSpacing.sm),
              SizedBox(
                width: 96,
                child: _LabeledField(
                  label: 'Size',
                  child: VioNumericField(
                    value: shape.fontSize,
                    min: 1,
                    max: 512,
                    label: 'px',
                    onChanged: (value) {
                      final updated = shape.copyWith(fontSize: value);
                      _emitUpdated(context, updated, relayoutText: true);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: VioSpacing.sm),

          // Line height + Letter spacing
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                  label: 'Line height',
                  child: Row(
                    children: [
                      Expanded(
                        child: VioNumericField(
                          value: shape.lineHeight == null
                              ? null
                              : (shape.lineHeight! * 100),
                          min: 0,
                          max: 2000,
                          enabled: !isAutoLineHeight,
                          label: '%',
                          onChanged: (value) {
                            final updated = shape.copyWith(
                              lineHeight: value / 100.0,
                            );
                            _emitUpdated(context, updated, relayoutText: true);
                          },
                        ),
                      ),
                      const SizedBox(width: VioSpacing.xs),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: Checkbox(
                              value: isAutoLineHeight,
                              onChanged: (value) {
                                final updated = shape.copyWith(
                                  lineHeight: (value ?? false)
                                      ? null
                                      : (shape.lineHeight ?? 1.2),
                                );
                                _emitUpdated(
                                  context,
                                  updated,
                                  relayoutText: true,
                                );
                              },
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Auto',
                            style: VioTypography.caption.copyWith(
                              color: VioColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: VioSpacing.sm),
              SizedBox(
                width: 120,
                child: _LabeledField(
                  label: 'Letter',
                  child: VioNumericField(
                    value: shape.letterSpacingPercent,
                    min: -100,
                    max: 500,
                    label: '%',
                    onChanged: (value) {
                      final updated = shape.copyWith(
                        letterSpacingPercent: value,
                      );
                      _emitUpdated(context, updated, relayoutText: true);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: VioSpacing.sm),

          // Text alignment
          _LabeledField(
            label: 'Align',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                VioIconButton(
                  icon: Icons.format_align_left,
                  tooltip: 'Left',
                  isSelected: _isLeftAligned(shape.textAlign),
                  onPressed: () {
                    final updated = shape.copyWith(textAlign: TextAlign.left);
                    _emitUpdated(context, updated, relayoutText: true);
                  },
                ),
                VioIconButton(
                  icon: Icons.format_align_center,
                  tooltip: 'Center',
                  isSelected: shape.textAlign == TextAlign.center,
                  onPressed: () {
                    final updated = shape.copyWith(textAlign: TextAlign.center);
                    _emitUpdated(context, updated, relayoutText: true);
                  },
                ),
                VioIconButton(
                  icon: Icons.format_align_right,
                  tooltip: 'Right',
                  isSelected: _isRightAligned(shape.textAlign),
                  onPressed: () {
                    final updated = shape.copyWith(textAlign: TextAlign.right);
                    _emitUpdated(context, updated, relayoutText: true);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _emitUpdated(
    BuildContext context,
    TextShape updated, {
    required bool relayoutText,
  }) {
    final shapeToSend = relayoutText ? _relayoutTextHeight(updated) : updated;
    final bloc = context.read<CanvasBloc>();
    bloc.add(ShapeUpdated(shapeToSend));

    // Google fonts may finish loading asynchronously after we measure.
    // When that happens, metrics can change and text can overflow unless we
    // re-measure. This keeps the box correct once the real font is ready.
    _relayoutAfterFontLoad(bloc: bloc, shape: shapeToSend);
  }

  Future<void> _relayoutAfterFontLoad({
    required CanvasBloc bloc,
    required TextShape shape,
  }) async {
    final text = shape.text;
    if (text.trim().isEmpty) return;

    final family = shape.fontFamily;
    if (family == null || family.isEmpty) return;

    FontWeight? fontWeight;
    final weightValue = shape.fontWeight;
    if (weightValue != null) {
      fontWeight = FontWeight.values.firstWhere(
        (w) => w.value == weightValue,
        orElse: () => FontWeight.w400,
      );
    }

    final letterSpacing = shape.letterSpacingPercent == 0
        ? null
        : shape.fontSize * (shape.letterSpacingPercent / 100.0);

    final baseStyle = TextStyle(
      fontSize: shape.fontSize,
      fontWeight: fontWeight,
      height: shape.lineHeight,
      letterSpacing: letterSpacing,
    );

    TextStyle resolvedStyle;
    try {
      resolvedStyle = GoogleFonts.getFont(family, textStyle: baseStyle);
    } catch (_) {
      // Not a Google font (system/unknown) => nothing to await.
      return;
    }

    try {
      // Wait for the font to load, then re-measure against the real metrics.
      await GoogleFonts.pendingFonts([resolvedStyle]);
    } catch (_) {
      // Best-effort only.
      return;
    }

    final latest = bloc.state.shapes[shape.id];
    if (latest is! TextShape) return;

    // Reuse the same relayout logic (grow-only) now that the font is ready.
    final relayout = _relayoutTextHeight(latest);
    if (relayout.textWidth == latest.textWidth &&
        relayout.textHeight == latest.textHeight) {
      return;
    }

    bloc.add(ShapeUpdated(relayout));
  }

  TextShape _relayoutTextHeight(TextShape updated) {
    final text = updated.text;
    if (text.trim().isEmpty) {
      return updated;
    }

    FontWeight? fontWeight;
    final weightValue = updated.fontWeight;
    if (weightValue != null) {
      fontWeight = FontWeight.values.firstWhere(
        (w) => w.value == weightValue,
        orElse: () => FontWeight.w400,
      );
    }

    final letterSpacing = updated.letterSpacingPercent == 0
        ? null
        : updated.fontSize * (updated.letterSpacingPercent / 100.0);

    final baseStyle = TextStyle(
      fontSize: updated.fontSize,
      fontWeight: fontWeight,
      height: updated.lineHeight,
      letterSpacing: letterSpacing,
    );

    TextStyle resolveFontStyle() {
      final family = updated.fontFamily;
      if (family == null || family.isEmpty) {
        return baseStyle;
      }
      try {
        return GoogleFonts.getFont(family, textStyle: baseStyle);
      } catch (_) {
        return baseStyle.copyWith(fontFamily: family);
      }
    }

    final wrapWidth = (updated.textWidth <= 1 ? 200.0 : updated.textWidth)
        .clamp(1.0, double.infinity);

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: resolveFontStyle(),
      ),
      textAlign: updated.textAlign,
      textDirection: TextDirection.ltr,
    )..layout(
        // Force the paragraph width to the current text box width so
        // center/right alignment is computed within the box.
        minWidth: wrapWidth,
        maxWidth: wrapWidth,
      );

    final neededHeight = (painter.height + 2).clamp(1.0, double.infinity);

    final minWidth = updated.textWidth <= 1 ? 200.0 : updated.textWidth;
    final minHeight = updated.textHeight <= 1 ? 24.0 : updated.textHeight;

    // Keep width stable; only grow if the current width is effectively unset.
    final newWidth = math.max(minWidth, wrapWidth);
    final newHeight = math.max(minHeight, neededHeight);

    if (newWidth == updated.textWidth && newHeight == updated.textHeight) {
      return updated;
    }

    return updated.copyWith(textWidth: newWidth, textHeight: newHeight);
  }

  bool _isLeftAligned(TextAlign align) {
    return align == TextAlign.left || align == TextAlign.start;
  }

  bool _isRightAligned(TextAlign align) {
    return align == TextAlign.right || align == TextAlign.end;
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: VioTypography.caption.copyWith(
            color: VioColors.textTertiary,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: VioSpacing.sm),
      decoration: BoxDecoration(
        color: VioColors.surfaceElevated,
        borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
        border: Border.all(color: VioColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          style: VioTypography.caption.copyWith(
            color: VioColors.textPrimary,
          ),
          dropdownColor: VioColors.surfaceElevated,
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemLabel(item)),
                ),
              )
              .toList(growable: false),
          onChanged: (next) {
            if (next != null) {
              onChanged(next);
            }
          },
        ),
      ),
    );
  }
}

/// Section for editing blur properties
class BlurSection extends StatelessWidget {
  const BlurSection({
    required this.shape,
    super.key,
  });

  final Shape shape;

  @override
  Widget build(BuildContext context) {
    final blur = shape.blur;

    if (blur == null) {
      return Padding(
        padding: const EdgeInsets.all(VioSpacing.sm),
        child: Center(
          child: Text(
            'No blur',
            style: VioTypography.caption.copyWith(
              color: VioColors.textTertiary,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(VioSpacing.sm),
      child: Column(
        children: [
          Row(
            children: [
              VioSvgIconButton(
                assetPath: blur.hidden ? VioIcons.eyeOff : VioIcons.eye,
                size: 14,
                buttonSize: 24,
                onPressed: () {
                  _toggleBlurVisibility(context);
                },
              ),
              const SizedBox(width: VioSpacing.sm),
              Expanded(
                child: Text(
                  blur.type == BlurType.layer
                      ? 'Layer Blur'
                      : 'Background Blur',
                  style: VioTypography.caption.copyWith(
                    color: VioColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: VioSpacing.sm),
          VioPropertySlider(
            label: '',
            value: blur.value,
            onChanged: (value) {
              _updateBlurValue(context, value);
            },
          ),
        ],
      ),
    );
  }

  void _toggleBlurVisibility(BuildContext context) {
    final blur = shape.blur;
    if (blur == null) return;

    final newBlur = ShapeBlur(
      type: blur.type,
      value: blur.value,
      hidden: !blur.hidden,
    );

    final bloc = context.read<CanvasBloc>();
    bloc.add(ShapeUpdated(shape.copyWith(blur: newBlur)));
  }

  void _updateBlurValue(BuildContext context, double value) {
    final blur = shape.blur;
    if (blur == null) return;

    final newBlur = ShapeBlur(
      type: blur.type,
      value: value,
      hidden: blur.hidden,
    );

    final bloc = context.read<CanvasBloc>();
    bloc.add(ShapeUpdated(shape.copyWith(blur: newBlur)));
  }
}
