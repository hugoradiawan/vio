import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vio_core/vio_core.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../canvas/bloc/canvas_bloc.dart';
import 'gradient_editor.dart';

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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _FillItem extends StatefulWidget {
  const _FillItem({
    required this.fill,
    required this.index,
    required this.shape,
  });

  final ShapeFill fill;
  final int index;
  final Shape shape;

  @override
  State<_FillItem> createState() => _FillItemState();
}

class _FillItemState extends State<_FillItem> {
  bool _expanded = false;

  ShapeFill get fill => widget.fill;
  int get index => widget.index;
  Shape get shape => widget.shape;

  bool get _hasGradient => fill.gradient != null;

  @override
  void didUpdateWidget(covariant _FillItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-collapse when gradient is removed.
    if (oldWidget.fill.gradient != null && fill.gradient == null) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(VioSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Visibility toggle
              VioIconButton(
                icon: fill.hidden ? VioIcons.eyeOff : VioIcons.eye,
                iconSize: 14,
                size: 24,
                onPressed: () => _toggleFillVisibility(context),
              ),
              const SizedBox(width: VioSpacing.xs),
              // Color / gradient preview swatch
              GestureDetector(
                onTap: _hasGradient
                    ? () => setState(() => _expanded = !_expanded)
                    : () => _showColorPicker(context),
                child: _buildColorSwatch(),
              ),
              const SizedBox(width: VioSpacing.sm),
              // Hex value or gradient label
              Expanded(
                child: GestureDetector(
                  onTap: _hasGradient
                      ? () => setState(() => _expanded = !_expanded)
                      : null,
                  child: Container(
                    height: 32,
                    padding:
                        const EdgeInsets.symmetric(horizontal: VioSpacing.sm),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (_hasGradient) ...[
                          Icon(
                            fill.gradient!.type == GradientType.radial
                                ? Icons.radio_button_checked
                                : Icons.gradient,
                            size: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              fill.gradient!.type == GradientType.radial
                                  ? 'Radial'
                                  : 'Linear',
                              style: VioTypography.caption.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            _expanded ? Icons.expand_less : Icons.expand_more,
                            size: 14,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ] else ...[
                          Text(
                            '#',
                            style: VioTypography.caption.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              _colorToHex(fill.color),
                              style: VioTypography.caption.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: VioSpacing.xs),
              // Opacity (for solid fills)
              if (!_hasGradient)
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
              // Gradient expand toggle (compact)
              if (!_hasGradient)
                Tooltip(
                  message: 'Add gradient',
                  child: GestureDetector(
                    onTap: () {
                      _applyGradient(
                        context,
                        ShapeGradient(
                          type: GradientType.linear,
                          stops: [
                            GradientStop(color: fill.color, offset: 0.0),
                            const GradientStop(
                              color: 0xFFFFFFFF,
                              offset: 1.0,
                            ),
                          ],
                        ),
                      );
                      setState(() => _expanded = true);
                    },
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Center(
                        child: Icon(
                          Icons.gradient,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // ── Gradient Editor (expanded) ──
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(
                left: 28, // align with colour swatch
                top: VioSpacing.xs,
              ),
              child: GradientEditor(
                fill: fill,
                onChanged: (result) => _onGradientChanged(context, result),
              ),
            ),
        ],
      ),
    );
  }

  /// Build a 32×32 colour swatch — solid or gradient preview.
  Widget _buildColorSwatch() {
    if (_hasGradient) {
      final stops = fill.gradient!.stops;
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          gradient: LinearGradient(
            colors: stops
                .map((s) => Color(s.color).withValues(alpha: s.opacity))
                .toList(),
            stops: stops.map((s) => s.offset).toList(),
          ),
        ),
      );
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Color(fill.color),
        borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
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

  void _applyGradient(BuildContext context, ShapeGradient gradient) {
    final newFills = List<ShapeFill>.from(shape.fills);
    newFills[index] = fill.copyWith(gradient: gradient);
    _updateShape(context, newFills: newFills);
  }

  void _onGradientChanged(BuildContext context, GradientEditorResult result) {
    final newFills = List<ShapeFill>.from(shape.fills);
    if (result.gradient == null) {
      // Switched back to solid.
      newFills[index] = fill.copyWith(
        color: result.fillColor,
        clearGradient: true,
      );
      setState(() => _expanded = false);
    } else {
      newFills[index] = fill.copyWith(
        color: result.fillColor,
        gradient: result.gradient,
      );
    }
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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              VioIconButton(
                icon: stroke.hidden ? VioIcons.eyeOff : VioIcons.eye,
                iconSize: 14,
                size: 24,
                onPressed: () => _toggleStrokeVisibility(context),
              ),
              const SizedBox(width: VioSpacing.xs),
              // Color preview
              GestureDetector(
                onTap: () => _showColorPicker(context),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(stroke.color),
                      borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
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
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '#',
                        style: VioTypography.caption.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          _colorToHex(stroke.color),
                          style: VioTypography.caption.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
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
              Icon(
                VioIcons.strokeSize,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
                  border:
                      Border.all(color: Theme.of(context).colorScheme.outline),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<StrokeAlignment>(
                    value: stroke.alignment,
                    isDense: true,
                    style: VioTypography.caption.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    dropdownColor:
                        Theme.of(context).colorScheme.surfaceContainerHigh,
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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(VioSpacing.sm),
      child: Column(
        children: [
          // Header row: visibility, color, type dropdown, delete
          Row(
            children: [
              VioIconButton(
                icon: shadow.hidden ? VioIcons.eyeOff : VioIcons.eye,
                iconSize: 14,
                size: 24,
                onPressed: () => _toggleShadowVisibility(context),
              ),
              const SizedBox(width: VioSpacing.xs),
              // Color preview (tappable for color picker)
              GestureDetector(
                onTap: () => _showColorPicker(context),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color:
                          Color(shadow.color).withValues(alpha: shadow.opacity),
                      borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: VioSpacing.sm),
              // Shadow type dropdown
              Expanded(
                child: Container(
                  height: 28,
                  padding:
                      const EdgeInsets.symmetric(horizontal: VioSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ShadowStyle>(
                      value: shadow.style,
                      isDense: true,
                      isExpanded: true,
                      style: VioTypography.caption.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      dropdownColor:
                          Theme.of(context).colorScheme.surfaceContainerHigh,
                      items: ShadowStyle.values.map((style) {
                        return DropdownMenuItem(
                          value: style,
                          child: Text(
                            style == ShadowStyle.dropShadow
                                ? 'Drop Shadow'
                                : 'Inner Shadow',
                          ),
                        );
                      }).toList(),
                      onChanged: (style) {
                        if (style != null) {
                          _updateShadowStyle(context, style);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: VioSpacing.xs),
              // Delete button
              VioIconButton(
                icon: VioIcons.close,
                iconSize: 12,
                size: 24,
                onPressed: () => _removeShadow(context),
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

  Future<void> _showColorPicker(BuildContext context) async {
    final shadow = shape.shadow;
    if (shadow == null) return;

    final result = await VioColorPickerDialog.show(
      context,
      initialColor: shadow.color,
      initialOpacity: shadow.opacity,
    );
    if (result != null && context.mounted) {
      final newShadow = ShapeShadow(
        id: shadow.id,
        style: shadow.style,
        color: result.color,
        opacity: result.opacity,
        offsetX: shadow.offsetX,
        offsetY: shadow.offsetY,
        blur: shadow.blur,
        spread: shadow.spread,
        hidden: shadow.hidden,
      );
      final bloc = context.read<CanvasBloc>();
      bloc.add(ShapeUpdated(shape.copyWith(shadow: newShadow)));
    }
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

  void _updateShadowStyle(BuildContext context, ShadowStyle style) {
    final shadow = shape.shadow;
    if (shadow == null) return;

    final newShadow = ShapeShadow(
      id: shadow.id,
      style: style,
      color: shadow.color,
      opacity: shadow.opacity,
      offsetX: shadow.offsetX,
      offsetY: shadow.offsetY,
      blur: shadow.blur,
      spread: shadow.spread,
      hidden: shadow.hidden,
    );

    final bloc = context.read<CanvasBloc>();
    bloc.add(ShapeUpdated(shape.copyWith(shadow: newShadow)));
  }

  void _removeShadow(BuildContext context) {
    final bloc = context.read<CanvasBloc>();
    bloc.add(ShapeUpdated(shape.copyWith()));
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          style: VioTypography.caption.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          dropdownColor: Theme.of(context).colorScheme.surfaceContainerHigh,
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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(VioSpacing.sm),
      child: Column(
        children: [
          // Header row: visibility, type dropdown, delete
          Row(
            children: [
              VioIconButton(
                icon: blur.hidden ? VioIcons.eyeOff : VioIcons.eye,
                iconSize: 14,
                size: 24,
                onPressed: () => _toggleBlurVisibility(context),
              ),
              const SizedBox(width: VioSpacing.sm),
              // Blur type dropdown
              Expanded(
                child: Container(
                  height: 28,
                  padding:
                      const EdgeInsets.symmetric(horizontal: VioSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<BlurType>(
                      value: blur.type,
                      isDense: true,
                      isExpanded: true,
                      style: VioTypography.caption.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      dropdownColor:
                          Theme.of(context).colorScheme.surfaceContainerHigh,
                      items: BlurType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(
                            type == BlurType.layer
                                ? 'Layer Blur'
                                : 'Background Blur',
                          ),
                        );
                      }).toList(),
                      onChanged: (type) {
                        if (type != null) {
                          _updateBlurType(context, type);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: VioSpacing.xs),
              // Delete button
              VioIconButton(
                icon: VioIcons.close,
                iconSize: 12,
                size: 24,
                onPressed: () => _removeBlur(context),
              ),
            ],
          ),
          const SizedBox(height: VioSpacing.sm),
          // Value slider with label
          VioNumericField(
            label: 'Amount',
            value: blur.value,
            min: 0,
            max: 100,
            onChanged: (value) => _updateBlurValue(context, value),
          ),
        ],
      ),
    );
  }

  void _toggleBlurVisibility(BuildContext context) {
    final blur = shape.blur;
    if (blur == null) return;

    final newBlur = ShapeBlur(
      id: blur.id,
      type: blur.type,
      value: blur.value,
      hidden: !blur.hidden,
    );

    final bloc = context.read<CanvasBloc>();
    bloc.add(ShapeUpdated(shape.copyWith(blur: newBlur)));
  }

  void _updateBlurType(BuildContext context, BlurType type) {
    final blur = shape.blur;
    if (blur == null) return;

    final newBlur = ShapeBlur(
      id: blur.id,
      type: type,
      value: blur.value,
      hidden: blur.hidden,
    );

    final bloc = context.read<CanvasBloc>();
    bloc.add(ShapeUpdated(shape.copyWith(blur: newBlur)));
  }

  void _removeBlur(BuildContext context) {
    final bloc = context.read<CanvasBloc>();
    bloc.add(ShapeUpdated(shape.copyWith()));
  }

  void _updateBlurValue(BuildContext context, double value) {
    final blur = shape.blur;
    if (blur == null) return;

    final newBlur = ShapeBlur(
      id: blur.id,
      type: blur.type,
      value: value,
      hidden: blur.hidden,
    );

    final bloc = context.read<CanvasBloc>();
    bloc.add(ShapeUpdated(shape.copyWith(blur: newBlur)));
  }
}
