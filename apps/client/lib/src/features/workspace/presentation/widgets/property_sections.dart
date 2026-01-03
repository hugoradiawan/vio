import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
            assetPath: VioIcons.eye,
            size: 14,
            buttonSize: 24,
            onPressed: () {
              // TODO: Toggle fill visibility
            },
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

  void _showColorPicker(BuildContext context) {
    // TODO: Show color picker dialog
  }

  void _updateFillOpacity(BuildContext context, double opacity) {
    final newFills = List<ShapeFill>.from(shape.fills);
    newFills[index] = ShapeFill(
      color: fill.color,
      opacity: opacity,
      gradient: fill.gradient,
    );
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
                assetPath: VioIcons.eye,
                size: 14,
                buttonSize: 24,
                onPressed: () {
                  // TODO: Toggle stroke visibility
                },
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

  void _showColorPicker(BuildContext context) {
    // TODO: Show color picker dialog
  }

  void _updateStrokeOpacity(BuildContext context, double opacity) {
    final newStrokes = List<ShapeStroke>.from(shape.strokes);
    newStrokes[index] = stroke.copyWith(opacity: opacity);
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
