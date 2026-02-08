import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vio_core/vio_core.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

/// Result returned when the gradient editor produces a change.
class GradientEditorResult {
  const GradientEditorResult({required this.fillColor, this.gradient});

  /// The updated gradient, or null if switched back to solid.
  final ShapeGradient? gradient;

  /// The solid color value (always kept in sync).
  final int fillColor;
}

/// Fill type for the selector.
enum FillType { solid, linear, radial }

/// A compact gradient editor embedded in the fill section.
///
/// Shows a fill-type selector (solid / linear / radial), a gradient preview
/// bar with draggable colour stops, and per-stop colour/opacity editing.
class GradientEditor extends StatefulWidget {
  const GradientEditor({
    required this.fill,
    required this.onChanged,
    super.key,
  });

  final ShapeFill fill;

  /// Called whenever the gradient or fill type changes.
  final ValueChanged<GradientEditorResult> onChanged;

  @override
  State<GradientEditor> createState() => _GradientEditorState();
}

class _GradientEditorState extends State<GradientEditor> {
  late FillType _fillType;
  late ShapeGradient? _gradient;
  int _selectedStopIndex = 0;

  @override
  void initState() {
    super.initState();
    _syncFromFill();
  }

  @override
  void didUpdateWidget(covariant GradientEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fill != widget.fill) {
      _syncFromFill();
    }
  }

  void _syncFromFill() {
    if (widget.fill.gradient == null) {
      _fillType = FillType.solid;
      _gradient = null;
    } else {
      _fillType = widget.fill.gradient!.type == GradientType.radial
          ? FillType.radial
          : FillType.linear;
      _gradient = widget.fill.gradient;
    }
    _selectedStopIndex = 0;
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  ShapeGradient _defaultGradient(GradientType type) {
    // Derive from the current solid colour so the transition feels natural.
    final baseColor = widget.fill.color;
    return ShapeGradient(
      type: type,
      startX: type == GradientType.radial ? 0.5 : 0.0,
      startY: type == GradientType.radial ? 0.5 : 0.0,
      endY: type == GradientType.radial ? 0.5 : 1.0,
      stops: [
        GradientStop(color: baseColor, offset: 0.0),
        const GradientStop(color: 0xFFFFFFFF, offset: 1.0),
      ],
    );
  }

  void _emitChange({ShapeGradient? gradient, int? fillColor}) {
    final effectiveGradient = gradient ?? _gradient;
    final effectiveColor = fillColor ?? widget.fill.color;
    widget.onChanged(
      GradientEditorResult(
        gradient: effectiveGradient,
        fillColor: effectiveColor,
      ),
    );
  }

  // ── Fill Type Selector ───────────────────────────────────────────────

  void _onFillTypeChanged(FillType type) {
    setState(() {
      _fillType = type;
      if (type == FillType.solid) {
        _gradient = null;
        _emitChange();
      } else {
        final gradientType =
            type == FillType.radial ? GradientType.radial : GradientType.linear;
        // Preserve existing gradient if just switching linear<->radial.
        if (_gradient != null) {
          _gradient = ShapeGradient(
            type: gradientType,
            stops: _gradient!.stops,
            startX: _gradient!.startX,
            startY: _gradient!.startY,
            endX: _gradient!.endX,
            endY: _gradient!.endY,
          );
        } else {
          _gradient = _defaultGradient(gradientType);
          _selectedStopIndex = 0;
        }
        _emitChange();
      }
    });
  }

  // ── Stop Actions ─────────────────────────────────────────────────────

  void _addStop() {
    if (_gradient == null) return;
    final stops = List<GradientStop>.from(_gradient!.stops);

    // Insert midway between last two stops.
    final lastIndex = stops.length - 1;
    final prevStop = stops[math.max(0, lastIndex - 1)];
    final lastStop = stops[lastIndex];
    final midOffset = (prevStop.offset + lastStop.offset) / 2;
    // Blend colours naively by averaging ARGB.
    final blendedColor = _blendColors(prevStop.color, lastStop.color);

    stops.insert(
      lastIndex,
      GradientStop(
        color: blendedColor,
        offset: midOffset,
      ),
    );
    _gradient = ShapeGradient(
      type: _gradient!.type,
      stops: stops,
      startX: _gradient!.startX,
      startY: _gradient!.startY,
      endX: _gradient!.endX,
      endY: _gradient!.endY,
    );
    setState(() {
      _selectedStopIndex = lastIndex;
    });
    _emitChange(gradient: _gradient);
  }

  void _removeStop(int index) {
    if (_gradient == null || _gradient!.stops.length <= 2) return;
    final stops = List<GradientStop>.from(_gradient!.stops)..removeAt(index);
    _gradient = ShapeGradient(
      type: _gradient!.type,
      stops: stops,
      startX: _gradient!.startX,
      startY: _gradient!.startY,
      endX: _gradient!.endX,
      endY: _gradient!.endY,
    );
    setState(() {
      _selectedStopIndex = _selectedStopIndex.clamp(0, stops.length - 1);
    });
    _emitChange(gradient: _gradient);
  }

  void _updateStopOffset(int index, double offset) {
    if (_gradient == null) return;
    final stops = List<GradientStop>.from(_gradient!.stops);
    stops[index] = GradientStop(
      color: stops[index].color,
      offset: offset.clamp(0.0, 1.0),
      opacity: stops[index].opacity,
    );
    _gradient = ShapeGradient(
      type: _gradient!.type,
      stops: stops,
      startX: _gradient!.startX,
      startY: _gradient!.startY,
      endX: _gradient!.endX,
      endY: _gradient!.endY,
    );
    setState(() {});
    _emitChange(gradient: _gradient);
  }

  Future<void> _editStopColor(int index) async {
    if (_gradient == null) return;
    final stop = _gradient!.stops[index];
    final result = await VioColorPickerDialog.show(
      context,
      initialColor: stop.color,
      initialOpacity: stop.opacity,
    );
    if (result == null || !mounted) return;
    final stops = List<GradientStop>.from(_gradient!.stops);
    stops[index] = GradientStop(
      color: result.color,
      offset: stop.offset,
      opacity: result.opacity,
    );
    _gradient = ShapeGradient(
      type: _gradient!.type,
      stops: stops,
      startX: _gradient!.startX,
      startY: _gradient!.startY,
      endX: _gradient!.endX,
      endY: _gradient!.endY,
    );
    setState(() {});
    _emitChange(gradient: _gradient);
  }

  // ── Direction ────────────────────────────────────────────────────────

  void _reverseDirection() {
    if (_gradient == null) return;
    _gradient = ShapeGradient(
      type: _gradient!.type,
      stops: _gradient!.stops,
      startX: _gradient!.endX,
      startY: _gradient!.endY,
      endX: _gradient!.startX,
      endY: _gradient!.startY,
    );
    setState(() {});
    _emitChange(gradient: _gradient);
  }

  void _setAngle(double angleDeg) {
    if (_gradient == null) return;
    final rad = angleDeg * math.pi / 180.0;
    // Compute start/end normalised to 0..1
    final dx = math.cos(rad);
    final dy = math.sin(rad);
    _gradient = ShapeGradient(
      type: _gradient!.type,
      stops: _gradient!.stops,
      startX: 0.5 - dx * 0.5,
      startY: 0.5 - dy * 0.5,
      endX: 0.5 + dx * 0.5,
      endY: 0.5 + dy * 0.5,
    );
    setState(() {});
    _emitChange(gradient: _gradient);
  }

  double get _currentAngle {
    if (_gradient == null) return 0;
    final dx = _gradient!.endX - _gradient!.startX;
    final dy = _gradient!.endY - _gradient!.startY;
    return math.atan2(dy, dx) * 180.0 / math.pi;
  }

  // ── Utilities ────────────────────────────────────────────────────────

  static int _blendColors(int a, int b) {
    final cA = Color(a);
    final cB = Color(b);
    return Color.fromARGB(
      ((cA.a + cB.a) / 2).round(),
      ((cA.r + cB.r) / 2).round(),
      ((cA.g + cB.g) / 2).round(),
      ((cA.b + cB.b) / 2).round(),
    ).toARGB32();
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Fill Type Selector ──
        _buildFillTypeSelector(),
        if (_fillType != FillType.solid) ...[
          const SizedBox(height: VioSpacing.xs),
          // ── Gradient Preview Bar with Stops ──
          _buildGradientPreview(),
          const SizedBox(height: VioSpacing.xs),
          // ── Direction Controls ──
          _buildDirectionControls(),
          const SizedBox(height: VioSpacing.xs),
          // ── Stop List ──
          _buildStopList(),
        ],
      ],
    );
  }

  // ── Fill Type Selector Buttons ───────────────────────────────────────

  Widget _buildFillTypeSelector() {
    return Row(
      children: [
        _fillTypeButton(FillType.solid, Icons.square_rounded, 'Solid'),
        const SizedBox(width: 2),
        _fillTypeButton(FillType.linear, Icons.gradient, 'Linear'),
        const SizedBox(width: 2),
        _fillTypeButton(
          FillType.radial,
          Icons.radio_button_checked,
          'Radial',
        ),
      ],
    );
  }

  Widget _fillTypeButton(FillType type, IconData icon, String tooltip) {
    final isSelected = _fillType == type;
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: isSelected
              ? VioColors.primary.withValues(alpha: 0.2)
              : VioColors.surfaceElevated,
          borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
          child: InkWell(
            borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
            onTap: () => _onFillTypeChanged(type),
            child: Container(
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
                border: Border.all(
                  color: isSelected ? VioColors.primary : VioColors.border,
                ),
              ),
              child: Icon(
                icon,
                size: 14,
                color: isSelected ? VioColors.primary : VioColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Gradient Preview Bar ─────────────────────────────────────────────

  /// Key used to look up the gradient bar's position on screen.
  final GlobalKey _barKey = GlobalKey();

  Widget _buildGradientPreview() {
    if (_gradient == null) return const SizedBox.shrink();
    final stops = _gradient!.stops;

    return SizedBox(
      height: 36,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = constraints.maxWidth;
          return GestureDetector(
            // Tap on the bar selects the nearest stop.
            onTapDown: (details) {
              final tapOffset = details.localPosition.dx / barWidth;
              _selectNearestStop(tapOffset);
            },
            // Drag anywhere on the bar moves the currently selected stop.
            onHorizontalDragStart: (details) {
              final tapOffset = details.localPosition.dx / barWidth;
              _selectNearestStop(tapOffset);
            },
            onHorizontalDragUpdate: (details) {
              final newOffset = details.localPosition.dx / barWidth;
              _updateStopOffset(_selectedStopIndex, newOffset);
            },
            child: Stack(
              key: _barKey,
              clipBehavior: Clip.none,
              children: [
                // Gradient bar
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
                      gradient: LinearGradient(
                        colors: stops
                            .map(
                              (s) =>
                                  Color(s.color).withValues(alpha: s.opacity),
                            )
                            .toList(),
                        stops: stops.map((s) => s.offset).toList(),
                      ),
                    ),
                  ),
                ),
                // Stop handles (visual only — drag is handled by the bar)
                for (int i = 0; i < stops.length; i++)
                  _buildStopHandle(i, stops[i], barWidth),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Select the stop closest to [normalizedX] (0..1).
  void _selectNearestStop(double normalizedX) {
    if (_gradient == null) return;
    final stops = _gradient!.stops;
    var closestIndex = 0;
    var closestDist = double.infinity;
    for (int i = 0; i < stops.length; i++) {
      final dist = (stops[i].offset - normalizedX).abs();
      if (dist < closestDist) {
        closestDist = dist;
        closestIndex = i;
      }
    }
    setState(() => _selectedStopIndex = closestIndex);
  }

  Widget _buildStopHandle(int index, GradientStop stop, double barWidth) {
    final isSelected = index == _selectedStopIndex;
    const handleWidth = 12.0;
    final left = stop.offset * (barWidth - handleWidth);

    return Positioned(
      left: left,
      top: 0,
      bottom: 0,
      child: GestureDetector(
        onTap: () => setState(() => _selectedStopIndex = index),
        onDoubleTap: () => _editStopColor(index),
        child: Container(
          width: handleWidth,
          decoration: BoxDecoration(
            color: Color(stop.color).withValues(alpha: stop.opacity),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: isSelected ? VioColors.primary : Colors.white,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Direction Controls ───────────────────────────────────────────────

  Widget _buildDirectionControls() {
    if (_gradient == null) return const SizedBox.shrink();
    final isLinear = _gradient!.type == GradientType.linear;

    return Row(
      children: [
        if (isLinear) ...[
          // Angle display / input
          Text(
            'Angle',
            style: VioTypography.caption.copyWith(
              color: VioColors.textTertiary,
            ),
          ),
          const SizedBox(width: VioSpacing.xs),
          SizedBox(
            width: 56,
            child: VioNumericField(
              value: _currentAngle,
              min: -360,
              max: 360,
              onChanged: _setAngle,
            ),
          ),
          const SizedBox(width: VioSpacing.xs),
        ],
        // Reverse direction button
        Tooltip(
          message: 'Reverse direction',
          child: InkWell(
            borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
            onTap: _reverseDirection,
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
                border: Border.all(color: VioColors.border),
                color: VioColors.surfaceElevated,
              ),
              child: const Icon(
                Icons.swap_horiz,
                size: 14,
                color: VioColors.textSecondary,
              ),
            ),
          ),
        ),
        const Spacer(),
        // Add stop button
        Tooltip(
          message: 'Add colour stop',
          child: InkWell(
            borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
            onTap: _addStop,
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
                border: Border.all(color: VioColors.border),
                color: VioColors.surfaceElevated,
              ),
              child: const Icon(
                Icons.add,
                size: 14,
                color: VioColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Stop List ────────────────────────────────────────────────────────

  Widget _buildStopList() {
    if (_gradient == null) return const SizedBox.shrink();
    final stops = _gradient!.stops;

    return Column(
      children: [
        for (int i = 0; i < stops.length; i++) _buildStopRow(i, stops[i]),
      ],
    );
  }

  Widget _buildStopRow(int index, GradientStop stop) {
    final isSelected = index == _selectedStopIndex;
    final hexStr =
        (stop.color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

    return GestureDetector(
      onTap: () => setState(() => _selectedStopIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: VioSpacing.xs,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: isSelected ? VioColors.primary.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
        ),
        child: Row(
          children: [
            // Colour swatch
            GestureDetector(
              onTap: () => _editStopColor(index),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Color(stop.color).withValues(alpha: stop.opacity),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: VioColors.border),
                ),
              ),
            ),
            const SizedBox(width: VioSpacing.xs),
            // Hex
            Text(
              '#$hexStr',
              style: VioTypography.caption.copyWith(
                color: VioColors.textPrimary,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
            const Spacer(),
            // Offset (position) as percentage
            SizedBox(
              width: 44,
              child: VioNumericField(
                value: (stop.offset * 100).roundToDouble(),
                min: 0,
                max: 100,
                onChanged: (v) => _updateStopOffset(index, v / 100),
              ),
            ),
            const SizedBox(width: 2),
            Text(
              '%',
              style: VioTypography.caption.copyWith(
                color: VioColors.textTertiary,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: VioSpacing.xs),
            // Remove button (only if > 2 stops)
            if (_gradient!.stops.length > 2)
              GestureDetector(
                onTap: () => _removeStop(index),
                child: const Icon(
                  Icons.close,
                  size: 12,
                  color: VioColors.textTertiary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
