import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_core/vio_core.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../canvas/bloc/canvas_bloc.dart';
import '../../../canvas/models/frame_presets.dart';
import '../../bloc/workspace_bloc.dart';
import 'frame_preset_picker.dart';
import 'property_sections.dart';
import 'shape_properties.dart';

/// Right panel containing properties inspector for selected shapes
class RightPanel extends StatelessWidget {
  const RightPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: VioColors.surface1,
        border: Border(
          left: BorderSide(
            color: VioColors.border,
          ),
        ),
      ),
      child: BlocBuilder<CanvasBloc, CanvasState>(
        buildWhen: (previous, current) =>
            previous.selectedShapeIds != current.selectedShapeIds ||
            previous.shapes != current.shapes,
        builder: (context, state) {
          final selectedIds = state.selectedShapeIds;

          if (selectedIds.isEmpty) {
            return BlocBuilder<WorkspaceBloc, WorkspaceState>(
              buildWhen: (prev, curr) =>
                  prev.activeTool != curr.activeTool ||
                  prev.frameToolPresetId != curr.frameToolPresetId,
              builder: (context, workspaceState) {
                if (workspaceState.activeTool == CanvasTool.frame) {
                  return _FrameToolPanel(workspaceState: workspaceState);
                }
                return const _NoSelectionPanel();
              },
            );
          }

          if (selectedIds.length == 1) {
            final shape = state.shapes[selectedIds.first];
            if (shape == null) {
              return const _NoSelectionPanel();
            }
            return _SingleShapePanel(shape: shape);
          }

          // Multiple selection
          final selectedShapes = selectedIds
              .map((id) => state.shapes[id])
              .whereType<Shape>()
              .toList();
          return _MultipleSelectionPanel(shapes: selectedShapes);
        },
      ),
    );
  }
}

class _FrameToolPanel extends StatelessWidget {
  const _FrameToolPanel({required this.workspaceState});

  final WorkspaceState workspaceState;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader('Frame'),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                VioPanel(
                  title: 'Default preset',
                  child: FramePresetPicker(
                    value: workspaceState.frameToolPresetId,
                    onChanged: (presetId) {
                      context
                          .read<WorkspaceBloc>()
                          .add(FrameToolPresetChanged(presetId));
                    },
                  ),
                ),
                const SizedBox(height: VioSpacing.sm),
                Padding(
                  padding: const EdgeInsets.all(VioSpacing.sm),
                  child: Text(
                    'Tip: Click to create a frame using the default preset. Drag to create a custom size.',
                    style: VioTypography.caption.copyWith(
                      color: VioColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Panel shown when nothing is selected
class _NoSelectionPanel extends StatelessWidget {
  const _NoSelectionPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader('Design'),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 48,
                  color: VioColors.textTertiary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: VioSpacing.md),
                Text(
                  'Select a shape',
                  style: VioTypography.bodyMedium.copyWith(
                    color: VioColors.textTertiary,
                  ),
                ),
                const SizedBox(height: VioSpacing.xs),
                Text(
                  'to view and edit its properties',
                  style: VioTypography.caption.copyWith(
                    color: VioColors.textTertiary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Panel for single shape selection
class _SingleShapePanel extends StatelessWidget {
  const _SingleShapePanel({required this.shape});

  final Shape shape;

  @override
  Widget build(BuildContext context) {
    final isText = shape is TextShape;
    return Column(
      children: [
        _buildHeader(_getShapeTypeLabel(shape.type)),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Shape name
                _ShapeNameSection(shape: shape),

                // Position & Size (common to all shapes)
                VioPanel(
                  title: 'Transform',
                  child: PositionSizeSection(shape: shape),
                ),

                if (shape is TextShape)
                  VioPanel(
                    title: 'Typography',
                    child: TypographySection(shape: shape as TextShape),
                  ),

                // Shape-specific properties
                if (shape is RectangleShape)
                  VioPanel(
                    title: 'Rectangle',
                    child: RectangleProperties(shape: shape as RectangleShape),
                  ),
                if (shape is EllipseShape)
                  VioPanel(
                    title: 'Ellipse',
                    child: EllipseProperties(shape: shape as EllipseShape),
                  ),
                if (shape is FrameShape)
                  VioPanel(
                    title: 'Frame',
                    child: FrameProperties(shape: shape as FrameShape),
                  ),

                // Fill
                VioPanel(
                  title: 'Fill',
                  trailing: VioSvgIconButton(
                    assetPath: VioIcons.add,
                    size: 14,
                    buttonSize: 24,
                    onPressed: () => _addFill(context),
                    tooltip: 'Add fill',
                  ),
                  child: FillSection(shape: shape),
                ),

                if (!isText) ...[
                  // Stroke
                  VioPanel(
                    title: 'Stroke',
                    trailing: VioSvgIconButton(
                      assetPath: VioIcons.add,
                      size: 14,
                      buttonSize: 24,
                      onPressed: () => _addStroke(context),
                      tooltip: 'Add stroke',
                    ),
                    child: StrokeSection(shape: shape),
                  ),

                  // Effects
                  VioPanel(
                    title: 'Shadow',
                    trailing: VioSvgIconButton(
                      assetPath: VioIcons.add,
                      size: 14,
                      buttonSize: 24,
                      onPressed: () => _addShadow(context),
                      tooltip: 'Add shadow',
                    ),
                    child: ShadowSection(shape: shape),
                  ),

                  VioPanel(
                    title: 'Blur',
                    trailing: VioSvgIconButton(
                      assetPath: VioIcons.add,
                      size: 14,
                      buttonSize: 24,
                      onPressed: () => _addBlur(context),
                      tooltip: 'Add blur',
                    ),
                    child: BlurSection(shape: shape),
                  ),

                  // Opacity
                  VioPanel(
                    title: 'Opacity',
                    child: OpacitySection(shape: shape),
                  ),
                ],

                const SizedBox(height: VioSpacing.lg),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getShapeTypeLabel(ShapeType type) {
    switch (type) {
      case ShapeType.rectangle:
        return 'Rectangle';
      case ShapeType.ellipse:
        return 'Ellipse';
      case ShapeType.frame:
        return 'Frame';
      case ShapeType.path:
        return 'Path';
      case ShapeType.text:
        return 'Text';
      case ShapeType.group:
        return 'Group';
      case ShapeType.image:
        return 'Image';
      case ShapeType.svg:
        return 'SVG';
      case ShapeType.bool:
        return 'Boolean';
    }
  }

  void _addFill(BuildContext context) {
    final bloc = context.read<CanvasBloc>();
    final newFills = [
      ...shape.fills,
      const ShapeFill(color: 0xFF808080),
    ];
    bloc.add(ShapeUpdated(shape.copyWith(fills: newFills)));
  }

  void _addStroke(BuildContext context) {
    final bloc = context.read<CanvasBloc>();
    final newStrokes = [
      ...shape.strokes,
      const ShapeStroke(color: 0xFF000000),
    ];
    bloc.add(ShapeUpdated(shape.copyWith(strokes: newStrokes)));
  }

  void _addShadow(BuildContext context) {
    if (shape.shadow != null) return; // Only one shadow for now

    final bloc = context.read<CanvasBloc>();
    const newShadow = ShapeShadow(
      offsetX: 4,
    );
    bloc.add(ShapeUpdated(shape.copyWith(shadow: newShadow)));
  }

  void _addBlur(BuildContext context) {
    if (shape.blur != null) return; // Only one blur for now

    final bloc = context.read<CanvasBloc>();
    const newBlur = ShapeBlur(
      value: 4,
    );
    bloc.add(ShapeUpdated(shape.copyWith(blur: newBlur)));
  }
}

/// Section for editing shape name
class _ShapeNameSection extends StatefulWidget {
  const _ShapeNameSection({required this.shape});

  final Shape shape;

  @override
  State<_ShapeNameSection> createState() => _ShapeNameSectionState();
}

class _ShapeNameSectionState extends State<_ShapeNameSection> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.shape.name);
  }

  @override
  void didUpdateWidget(_ShapeNameSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shape.name != widget.shape.name && !_isEditing) {
      _controller.text = widget.shape.name;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(VioSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: VioColors.border),
        ),
      ),
      child: Row(
        children: [
          // Shape type icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: VioColors.surfaceElevated,
              borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
            ),
            child: Icon(
              _getShapeIcon(widget.shape.type),
              size: 18,
              color: VioColors.textSecondary,
            ),
          ),
          const SizedBox(width: VioSpacing.sm),
          // Editable name
          Expanded(
            child: _isEditing
                ? TextField(
                    controller: _controller,
                    autofocus: true,
                    style: VioTypography.bodyMedium.copyWith(
                      color: VioColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: _saveName,
                    onTapOutside: (_) => _saveName(_controller.text),
                  )
                : GestureDetector(
                    onDoubleTap: () => setState(() => _isEditing = true),
                    child: Text(
                      widget.shape.name,
                      style: VioTypography.bodyMedium.copyWith(
                        color: VioColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
          ),
          // Visibility toggle
          VioSvgIconButton(
            assetPath: widget.shape.hidden ? VioIcons.eyeOff : VioIcons.eye,
            size: 14,
            onPressed: () => _toggleVisibility(context),
            tooltip: widget.shape.hidden ? 'Show' : 'Hide',
          ),
          // Lock toggle
          VioSvgIconButton(
            assetPath: widget.shape.blocked ? VioIcons.lock : VioIcons.unlock,
            size: 14,
            onPressed: () => _toggleLock(context),
            tooltip: widget.shape.blocked ? 'Unlock' : 'Lock',
          ),
        ],
      ),
    );
  }

  IconData _getShapeIcon(ShapeType type) {
    switch (type) {
      case ShapeType.rectangle:
        return Icons.rectangle_outlined;
      case ShapeType.ellipse:
        return Icons.circle_outlined;
      case ShapeType.frame:
        return Icons.crop_square_outlined;
      case ShapeType.path:
        return Icons.gesture;
      case ShapeType.text:
        return Icons.text_fields;
      case ShapeType.group:
        return Icons.folder_outlined;
      case ShapeType.image:
        return Icons.image_outlined;
      case ShapeType.svg:
        return Icons.code;
      case ShapeType.bool:
        return Icons.merge_type;
    }
  }

  void _saveName(String name) {
    setState(() => _isEditing = false);
    if (name.isEmpty || name == widget.shape.name) return;

    final bloc = context.read<CanvasBloc>();
    bloc.add(ShapeRenamed(widget.shape.id, name));
  }

  void _toggleVisibility(BuildContext context) {
    final bloc = context.read<CanvasBloc>();
    bloc.add(ShapeVisibilityToggled(widget.shape.id));
  }

  void _toggleLock(BuildContext context) {
    final bloc = context.read<CanvasBloc>();
    bloc.add(ShapeLockToggled(widget.shape.id));
  }
}

/// Panel for multiple shape selection
class _MultipleSelectionPanel extends StatelessWidget {
  const _MultipleSelectionPanel({required this.shapes});

  final List<Shape> shapes;

  @override
  Widget build(BuildContext context) {
    final selectedFrames =
        shapes.whereType<FrameShape>().toList(growable: false);
    final allSelectedAreFrames =
        selectedFrames.length == shapes.length && shapes.isNotEmpty;

    return Column(
      children: [
        _buildHeader('Multiple Selection'),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Selection info
                Padding(
                  padding: const EdgeInsets.all(VioSpacing.md),
                  child: Container(
                    padding: const EdgeInsets.all(VioSpacing.md),
                    decoration: BoxDecoration(
                      color: VioColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.select_all,
                          size: 24,
                          color: VioColors.primary,
                        ),
                        const SizedBox(width: VioSpacing.md),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${shapes.length} objects selected',
                              style: VioTypography.bodyMedium.copyWith(
                                color: VioColors.textPrimary,
                              ),
                            ),
                            Text(
                              _getSelectionSummary(),
                              style: VioTypography.caption.copyWith(
                                color: VioColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Alignment tools
                VioPanel(
                  title: 'Alignment',
                  child: Padding(
                    padding: const EdgeInsets.all(VioSpacing.sm),
                    child: VioAlignmentButtons(
                      onAlignLeft: () =>
                          _alignShapes(context, Alignment.centerLeft),
                      onAlignCenterH: () =>
                          _alignShapes(context, Alignment.center),
                      onAlignRight: () =>
                          _alignShapes(context, Alignment.centerRight),
                      onAlignTop: () =>
                          _alignShapes(context, Alignment.topCenter),
                      onAlignCenterV: () =>
                          _alignShapes(context, Alignment.center),
                      onAlignBottom: () =>
                          _alignShapes(context, Alignment.bottomCenter),
                    ),
                  ),
                ),

                if (allSelectedAreFrames)
                  VioPanel(
                    title: 'Frame preset',
                    child: FramePresetPicker(
                      value: _matchedPresetIdForFrames(selectedFrames),
                      onChanged: (presetId) {
                        final preset =
                            presetId == null ? null : framePresetById(presetId);
                        if (preset == null) {
                          return;
                        }

                        final bloc = context.read<CanvasBloc>();
                        for (final frame in selectedFrames) {
                          bloc.add(
                            ShapeUpdated(
                              frame.copyWith(
                                frameWidth: preset.width,
                                frameHeight: preset.height,
                              ),
                            ),
                          );
                        }
                      },
                      categoryLabel: 'Preset category',
                      presetLabel: 'Preset size',
                    ),
                  ),

                // Bulk opacity
                VioPanel(
                  title: 'Opacity',
                  child: Padding(
                    padding: const EdgeInsets.all(VioSpacing.sm),
                    child: VioPropertySlider(
                      label: '',
                      value: _getAverageOpacity() * 100,
                      onChanged: (value) =>
                          _setAllOpacity(context, value / 100),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String? _matchedPresetIdForFrames(List<FrameShape> frames) {
    if (frames.isEmpty) return null;

    final first = frames.first;
    final sameSize = frames.every(
      (f) =>
          (f.frameWidth - first.frameWidth).abs() < 0.001 &&
          (f.frameHeight - first.frameHeight).abs() < 0.001,
    );
    if (!sameSize) return null;

    bool nearlyEqual(double a, double b) => (a - b).abs() < 0.001;
    for (final category in framePresetCategories) {
      for (final preset in category.items) {
        if (nearlyEqual(preset.width, first.frameWidth) &&
            nearlyEqual(preset.height, first.frameHeight)) {
          return preset.id;
        }
      }
    }

    return null;
  }

  String _getSelectionSummary() {
    final typeCounts = <ShapeType, int>{};
    for (final shape in shapes) {
      typeCounts[shape.type] = (typeCounts[shape.type] ?? 0) + 1;
    }

    return typeCounts.entries
        .map((e) => '${e.value} ${e.key.name}${e.value > 1 ? 's' : ''}')
        .join(', ');
  }

  double _getAverageOpacity() {
    if (shapes.isEmpty) return 1.0;
    return shapes.map((s) => s.opacity).reduce((a, b) => a + b) / shapes.length;
  }

  void _alignShapes(BuildContext context, Alignment alignment) {
    // TODO: Implement shape alignment
  }

  void _setAllOpacity(BuildContext context, double opacity) {
    final bloc = context.read<CanvasBloc>();
    for (final shape in shapes) {
      bloc.add(ShapeUpdated(shape.copyWith(opacity: opacity)));
    }
  }
}

/// Build panel header
Widget _buildHeader(String title) {
  return Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: VioSpacing.md),
    decoration: const BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: VioColors.border,
        ),
      ),
    ),
    child: Row(
      children: [
        Text(
          title,
          style: VioTypography.subtitle2.copyWith(
            color: VioColors.textPrimary,
          ),
        ),
      ],
    ),
  );
}
