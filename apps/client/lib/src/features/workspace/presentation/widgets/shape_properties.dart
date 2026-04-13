import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_core/vio_core.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../canvas/bloc/canvas_bloc.dart';
import '../../../canvas/models/frame_presets.dart';
import 'frame_preset_picker.dart';

/// Common position and size properties for all shapes
class PositionSizeSection extends StatelessWidget {
  const PositionSizeSection({
    required this.shape,
    super.key,
  });

  final Shape shape;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(VioSpacing.sm),
      child: Column(
        children: [
          // X, Y position
          Row(
            children: [
              Expanded(
                child: VioNumericField(
                  label: 'X',
                  value: shape.x,
                  onChanged: (value) => _updatePosition(context, x: value),
                ),
              ),
              const SizedBox(width: VioSpacing.sm),
              Expanded(
                child: VioNumericField(
                  label: 'Y',
                  value: shape.y,
                  onChanged: (value) => _updatePosition(context, y: value),
                ),
              ),
            ],
          ),
          const SizedBox(height: VioSpacing.sm),
          // Width, Height
          Row(
            children: [
              Expanded(
                child: VioNumericField(
                  label: 'W',
                  value: shape.width,
                  min: 1,
                  onChanged: (value) => _updateSize(context, width: value),
                ),
              ),
              const SizedBox(width: VioSpacing.sm),
              Expanded(
                child: VioNumericField(
                  label: 'H',
                  value: shape.height,
                  min: 1,
                  onChanged: (value) => _updateSize(context, height: value),
                ),
              ),
            ],
          ),
          const SizedBox(height: VioSpacing.sm),
          // Rotation and shape-specific properties
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      VioIcons.rotation,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: VioSpacing.xs),
                    Expanded(
                      child: VioNumericField(
                        value: shape.rotation,
                        min: -360,
                        max: 360,
                        onChanged: (value) => _updateRotation(context, value),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: VioSpacing.sm),
              Expanded(
                child: _buildShapeSpecificField(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShapeSpecificField(BuildContext context) {
    if (shape is RectangleShape) {
      final rect = shape as RectangleShape;
      return Row(
        children: [
          Icon(
            VioIcons.cornerRadius,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: VioSpacing.xs),
          Expanded(
            child: VioNumericField(
              value: rect.cornerRadius,
              min: 0,
              onChanged: (value) => _updateCornerRadius(context, value),
            ),
          ),
        ],
      );
    }

    if (shape is TextShape) {
      return const SizedBox.shrink();
    }

    // For other shapes, show opacity
    return Row(
      children: [
        Icon(
          Icons.opacity,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: VioSpacing.xs),
        Expanded(
          child: VioNumericField(
            value: shape.opacity * 100,
            min: 0,
            max: 100,
            onChanged: (value) => _updateOpacity(context, value / 100),
          ),
        ),
      ],
    );
  }

  void _updatePosition(BuildContext context, {double? x, double? y}) {
    final bloc = context.read<CanvasBloc>();
    Shape updatedShape;

    if (shape is RectangleShape) {
      final rect = shape as RectangleShape;
      updatedShape = rect.copyWith(x: x ?? rect.x, y: y ?? rect.y);
    } else if (shape is EllipseShape) {
      final ellipse = shape as EllipseShape;
      updatedShape = ellipse.copyWith(x: x ?? ellipse.x, y: y ?? ellipse.y);
    } else if (shape is FrameShape) {
      final frame = shape as FrameShape;
      updatedShape = frame.copyWith(x: x ?? frame.x, y: y ?? frame.y);
    } else {
      return;
    }

    bloc.add(ShapeUpdated(updatedShape));
  }

  void _updateSize(BuildContext context, {double? width, double? height}) {
    final bloc = context.read<CanvasBloc>();
    Shape updatedShape;

    if (shape is RectangleShape) {
      final rect = shape as RectangleShape;
      updatedShape = rect.copyWith(
        rectWidth: width ?? rect.rectWidth,
        rectHeight: height ?? rect.rectHeight,
      );
    } else if (shape is EllipseShape) {
      final ellipse = shape as EllipseShape;
      updatedShape = ellipse.copyWith(
        ellipseWidth: width ?? ellipse.ellipseWidth,
        ellipseHeight: height ?? ellipse.ellipseHeight,
      );
    } else if (shape is FrameShape) {
      final frame = shape as FrameShape;
      updatedShape = frame.copyWith(
        frameWidth: width ?? frame.frameWidth,
        frameHeight: height ?? frame.frameHeight,
      );
    } else {
      return;
    }

    bloc.add(ShapeUpdated(updatedShape));
  }

  void _updateRotation(BuildContext context, double rotation) {
    final bloc = context.read<CanvasBloc>();

    // Calculate the delta from current rotation
    final deltaAngle = rotation - shape.rotation;
    final deltaRadians = deltaAngle * math.pi / 180;

    // Rotate around shape's center
    final center = shape.bounds.center;
    final rotationMatrix = Matrix2D.rotationAt(
      deltaRadians,
      center.dx,
      center.dy,
    );

    // Apply rotation to existing transform
    final newTransform = shape.transform * rotationMatrix;

    bloc.add(
      ShapeUpdated(
        shape.copyWith(
          rotation: rotation,
          transform: newTransform,
        ),
      ),
    );
  }

  void _updateOpacity(BuildContext context, double opacity) {
    final bloc = context.read<CanvasBloc>();
    bloc.add(ShapeUpdated(shape.copyWith(opacity: opacity)));
  }

  void _updateCornerRadius(BuildContext context, double radius) {
    if (shape is! RectangleShape) return;

    final bloc = context.read<CanvasBloc>();
    final rect = shape as RectangleShape;
    final updatedShape = rect.copyWith(
      r1: radius,
      r2: radius,
      r3: radius,
      r4: radius,
    );
    bloc.add(ShapeUpdated(updatedShape));
  }
}

/// Properties specific to rectangle shapes
class RectangleProperties extends StatelessWidget {
  const RectangleProperties({
    required this.shape,
    super.key,
  });

  final RectangleShape shape;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(VioSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Corner Radius',
            style: VioTypography.caption.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: VioSpacing.sm),
          // Individual corner controls
          if (!shape.hasUniformCorners)
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: VioNumericField(
                        label: 'TL',
                        value: shape.r1,
                        min: 0,
                        onChanged: (value) => _updateCorner(context, r1: value),
                      ),
                    ),
                    const SizedBox(width: VioSpacing.sm),
                    Expanded(
                      child: VioNumericField(
                        label: 'TR',
                        value: shape.r2,
                        min: 0,
                        onChanged: (value) => _updateCorner(context, r2: value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: VioSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: VioNumericField(
                        label: 'BL',
                        value: shape.r4,
                        min: 0,
                        onChanged: (value) => _updateCorner(context, r4: value),
                      ),
                    ),
                    const SizedBox(width: VioSpacing.sm),
                    Expanded(
                      child: VioNumericField(
                        label: 'BR',
                        value: shape.r3,
                        min: 0,
                        onChanged: (value) => _updateCorner(context, r3: value),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          // Toggle for independent corners
          const SizedBox(height: VioSpacing.sm),
          Row(
            children: [
              VioIconButton(
                icon: shape.hasUniformCorners ? VioIcons.lock : VioIcons.unlock,
                iconSize: 14,
                size: 24,
                onPressed: () => _toggleIndependentCorners(context),
                tooltip: shape.hasUniformCorners
                    ? 'Enable independent corners'
                    : 'Lock corners together',
              ),
              const SizedBox(width: VioSpacing.sm),
              Text(
                shape.hasUniformCorners
                    ? 'Uniform corners'
                    : 'Independent corners',
                style: VioTypography.caption.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateCorner(
    BuildContext context, {
    double? r1,
    double? r2,
    double? r3,
    double? r4,
  }) {
    final bloc = context.read<CanvasBloc>();
    final updatedShape = shape.copyWith(
      r1: r1 ?? shape.r1,
      r2: r2 ?? shape.r2,
      r3: r3 ?? shape.r3,
      r4: r4 ?? shape.r4,
    );
    bloc.add(ShapeUpdated(updatedShape));
  }

  void _toggleIndependentCorners(BuildContext context) {
    // If currently uniform, just do nothing (user will change individual corners)
    // If currently independent, set all to the average
    if (!shape.hasUniformCorners) {
      final avg = (shape.r1 + shape.r2 + shape.r3 + shape.r4) / 4;
      final bloc = context.read<CanvasBloc>();
      final updatedShape = shape.copyWith(r1: avg, r2: avg, r3: avg, r4: avg);
      bloc.add(ShapeUpdated(updatedShape));
    }
  }
}

/// Properties specific to ellipse shapes
class EllipseProperties extends StatelessWidget {
  const EllipseProperties({
    required this.shape,
    super.key,
  });

  final EllipseShape shape;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(VioSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show if it's a circle
          if (shape.isCircle)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: VioSpacing.sm,
                vertical: VioSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
              ),
              child: Text(
                'Perfect Circle',
                style: VioTypography.caption.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          const SizedBox(height: VioSpacing.sm),
          // Radius display
          Row(
            children: [
              Text(
                'Radius X: ${shape.radiusX.toStringAsFixed(1)}',
                style: VioTypography.caption.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: VioSpacing.md),
              Text(
                'Radius Y: ${shape.radiusY.toStringAsFixed(1)}',
                style: VioTypography.caption.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Properties specific to frame shapes
class FrameProperties extends StatefulWidget {
  const FrameProperties({
    required this.shape,
    super.key,
  });

  final FrameShape shape;

  @override
  State<FrameProperties> createState() => _FramePropertiesState();
}

class _FramePropertiesState extends State<FrameProperties> {
  FrameShape get shape => widget.shape;

  @override
  Widget build(BuildContext context) {
    final matchedPresetId = _matchPresetIdForFrame(shape);

    return Padding(
      padding: const EdgeInsets.all(VioSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FramePresetPicker(
            value: matchedPresetId,
            onChanged: (presetId) {
              final preset =
                  presetId == null ? null : framePresetById(presetId);
              if (preset == null) {
                return;
              }

              final bloc = context.read<CanvasBloc>();
              bloc.add(
                ShapeUpdated(
                  shape.copyWith(
                    frameWidth: preset.width,
                    frameHeight: preset.height,
                  ),
                ),
              );
            },
            categoryLabel: 'Preset category',
            presetLabel: 'Preset size',
          ),
          const SizedBox(height: VioSpacing.sm),

          // Clip content toggle
          _buildToggleRow(
            context,
            label: 'Clip content',
            value: shape.clipContent,
            onChanged: (value) => _updateClipContent(context, value),
          ),
          const SizedBox(height: VioSpacing.sm),
          // Show content toggle
          _buildToggleRow(
            context,
            label: 'Show in layers',
            value: shape.showContent,
            onChanged: (value) => _updateShowContent(context, value),
          ),
          const SizedBox(height: VioSpacing.sm),
          // Device frame toggle
          _buildToggleRow(
            context,
            label: 'Show device frame',
            value: shape.showDeviceFrame,
            onChanged: (value) => _updateShowDeviceFrame(context, value),
          ),
          // Device frame dark mode (only when device frame is enabled)
          if (shape.showDeviceFrame) ...[            
            const SizedBox(height: VioSpacing.sm),
            _buildToggleRow(
              context,
              label: 'Dark mode',
              value: shape.deviceFrameDarkMode,
              onChanged: (value) => context.read<CanvasBloc>().add(
                    ShapeUpdated(shape.copyWith(deviceFrameDarkMode: value)),
                  ),
            ),
          ],
          const SizedBox(height: VioSpacing.sm),
          // Children count
          Text(
            '${shape.children.length} children',
            style: VioTypography.caption.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String? _matchPresetIdForFrame(FrameShape frame) {
    bool nearlyEqual(double a, double b) => (a - b).abs() < 0.001;

    for (final category in framePresetCategories) {
      for (final preset in category.items) {
        if (nearlyEqual(preset.width, frame.frameWidth) &&
            nearlyEqual(preset.height, frame.frameHeight)) {
          return preset.id;
        }
      }
    }

    return null;
  }

  Widget _buildToggleRow(
    BuildContext context, {
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: VioSpacing.xs),
        child: Row(
          children: [
            Icon(
              value ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
              color: value
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: VioSpacing.sm),
            Text(
              label,
              style: VioTypography.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateClipContent(BuildContext context, bool value) {
    final bloc = context.read<CanvasBloc>();
    bloc.add(ShapeUpdated(shape.copyWith(clipContent: value)));
  }

  void _updateShowContent(BuildContext context, bool value) {
    final bloc = context.read<CanvasBloc>();
    bloc.add(ShapeUpdated(shape.copyWith(showContent: value)));
  }

  void _updateShowDeviceFrame(BuildContext context, bool value) {
    final bloc = context.read<CanvasBloc>();
    bloc.add(ShapeUpdated(shape.copyWith(showDeviceFrame: value)));
  }
}

/// Opacity section for all shapes
class OpacitySection extends StatelessWidget {
  const OpacitySection({
    required this.shape,
    super.key,
  });

  final Shape shape;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(VioSpacing.sm),
      child: VioPropertySlider(
        label: '',
        value: shape.opacity * 100,
        onChanged: (value) {
          final bloc = context.read<CanvasBloc>();
          bloc.add(ShapeUpdated(shape.copyWith(opacity: value / 100)));
        },
      ),
    );
  }
}
