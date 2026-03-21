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
class RightPanel extends StatefulWidget {
  const RightPanel({
    required this.width,
    super.key,
  });

  /// Width of the panel in logical pixels.
  final double width;

  @override
  State<RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends State<RightPanel> {
  final Map<String, bool> _expandedSections = <String, bool>{};

  bool _isSectionExpanded(String key, {bool defaultValue = true}) {
    return _expandedSections[key] ?? defaultValue;
  }

  void _setSectionExpanded(String key, bool expanded) {
    setState(() {
      _expandedSections[key] = expanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.25),
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
            return _SingleShapePanel(
              shape: shape,
              isSectionExpanded: _isSectionExpanded,
              onSectionExpansionChanged: _setSectionExpanded,
            );
          }

          // Multiple selection
          final selectedShapes = selectedIds
              .map((id) => state.shapes[id])
              .whereType<Shape>()
              .toList();
          return _MultipleSelectionPanel(
            shapes: selectedShapes,
            isSectionExpanded: _isSectionExpanded,
            onSectionExpansionChanged: _setSectionExpanded,
          );
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
        _buildHeader(context, 'Frame'),
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        _buildHeader(context, 'Design'),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 48,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.5),
                ),
                const SizedBox(height: VioSpacing.md),
                Text(
                  'Select a shape',
                  style: VioTypography.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: VioSpacing.xs),
                Text(
                  'to view and edit its properties',
                  style: VioTypography.caption.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.7),
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
  const _SingleShapePanel({
    required this.shape,
    required this.isSectionExpanded,
    required this.onSectionExpansionChanged,
  });

  final Shape shape;
  final bool Function(String key, {bool defaultValue}) isSectionExpanded;
  final void Function(String key, bool expanded) onSectionExpansionChanged;

  String _sectionKey(String section) => 'single:$section';

  @override
  Widget build(BuildContext context) {
    final isText = shape is TextShape;
    return Column(
      children: [
        _buildHeader(context, _getShapeTypeLabel(shape.type)),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Shape name
                _ShapeNameSection(shape: shape),

                // Position & Size (common to all shapes)
                VioPanel(
                  title: 'Transform',
                  collapsible: true,
                  isExpanded: isSectionExpanded(_sectionKey('transform')),
                  onExpansionChanged: (expanded) => onSectionExpansionChanged(
                    _sectionKey('transform'),
                    expanded,
                  ),
                  child: PositionSizeSection(shape: shape),
                ),

                if (shape is TextShape)
                  VioPanel(
                    title: 'Typography',
                    collapsible: true,
                    isExpanded: isSectionExpanded(_sectionKey('typography')),
                    onExpansionChanged: (expanded) => onSectionExpansionChanged(
                      _sectionKey('typography'),
                      expanded,
                    ),
                    child: TypographySection(shape: shape as TextShape),
                  ),

                // Shape-specific properties
                if (shape is RectangleShape)
                  VioPanel(
                    title: 'Rectangle',
                    collapsible: true,
                    isExpanded: isSectionExpanded(_sectionKey('rectangle')),
                    onExpansionChanged: (expanded) => onSectionExpansionChanged(
                      _sectionKey('rectangle'),
                      expanded,
                    ),
                    child: RectangleProperties(shape: shape as RectangleShape),
                  ),
                if (shape is EllipseShape)
                  VioPanel(
                    title: 'Ellipse',
                    collapsible: true,
                    isExpanded: isSectionExpanded(_sectionKey('ellipse')),
                    onExpansionChanged: (expanded) => onSectionExpansionChanged(
                      _sectionKey('ellipse'),
                      expanded,
                    ),
                    child: EllipseProperties(shape: shape as EllipseShape),
                  ),
                if (shape is FrameShape)
                  VioPanel(
                    title: 'Frame',
                    collapsible: true,
                    isExpanded: isSectionExpanded(_sectionKey('frame')),
                    onExpansionChanged: (expanded) => onSectionExpansionChanged(
                      _sectionKey('frame'),
                      expanded,
                    ),
                    child: FrameProperties(shape: shape as FrameShape),
                  ),

                // Fill
                VioPanel(
                  title: 'Fill',
                  collapsible: true,
                  isExpanded: isSectionExpanded(_sectionKey('fill')),
                  onExpansionChanged: (expanded) => onSectionExpansionChanged(
                    _sectionKey('fill'),
                    expanded,
                  ),
                  trailing: VioIconButton(
                    icon: VioIcons.add,
                    iconSize: 14,
                    size: 24,
                    onPressed: () => _addFill(context),
                    tooltip: 'Add fill',
                  ),
                  child: FillSection(shape: shape),
                ),

                if (!isText) ...[
                  // Stroke
                  VioPanel(
                    title: 'Stroke',
                    collapsible: true,
                    isExpanded: isSectionExpanded(_sectionKey('stroke')),
                    onExpansionChanged: (expanded) => onSectionExpansionChanged(
                      _sectionKey('stroke'),
                      expanded,
                    ),
                    trailing: VioIconButton(
                      icon: VioIcons.add,
                      iconSize: 14,
                      size: 24,
                      onPressed: () => _addStroke(context),
                      tooltip: 'Add stroke',
                    ),
                    child: StrokeSection(shape: shape),
                  ),

                  // Effects
                  VioPanel(
                    title: 'Shadow',
                    collapsible: true,
                    isExpanded: isSectionExpanded(_sectionKey('shadow')),
                    onExpansionChanged: (expanded) => onSectionExpansionChanged(
                      _sectionKey('shadow'),
                      expanded,
                    ),
                    trailing: VioIconButton(
                      icon: VioIcons.add,
                      iconSize: 14,
                      size: 24,
                      onPressed: () => _addShadow(context),
                      tooltip: 'Add shadow',
                    ),
                    child: ShadowSection(shape: shape),
                  ),

                  VioPanel(
                    title: 'Blur',
                    collapsible: true,
                    isExpanded: isSectionExpanded(_sectionKey('blur')),
                    onExpansionChanged: (expanded) => onSectionExpansionChanged(
                      _sectionKey('blur'),
                      expanded,
                    ),
                    trailing: VioIconButton(
                      icon: VioIcons.add,
                      iconSize: 14,
                      size: 24,
                      onPressed: () => _addBlur(context),
                      tooltip: 'Add blur',
                    ),
                    child: BlurSection(shape: shape),
                  ),

                  // Opacity
                  VioPanel(
                    title: 'Opacity',
                    collapsible: true,
                    isExpanded: isSectionExpanded(_sectionKey('opacity')),
                    onExpansionChanged: (expanded) => onSectionExpansionChanged(
                      _sectionKey('opacity'),
                      expanded,
                    ),
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
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .outline
                  .withValues(alpha: 0.25)),
        ),
      ),
      child: Row(
        children: [
          // Shape type icon
          SizedBox(
            width: 32,
            height: 32,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
              ),
              child: Icon(
                _getShapeIcon(widget.shape.type),
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
                      color: Theme.of(context).colorScheme.onSurface,
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
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
          ),
          // Visibility toggle
          VioIconButton(
            icon: widget.shape.hidden ? VioIcons.eyeOff : VioIcons.eye,
            iconSize: 14,
            onPressed: () => _toggleVisibility(context),
            tooltip: widget.shape.hidden ? 'Show' : 'Hide',
          ),
          // Lock toggle
          VioIconButton(
            icon: widget.shape.blocked ? VioIcons.lock : VioIcons.unlock,
            iconSize: 14,
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
  const _MultipleSelectionPanel({
    required this.shapes,
    required this.isSectionExpanded,
    required this.onSectionExpansionChanged,
  });

  final List<Shape> shapes;
  final bool Function(String key, {bool defaultValue}) isSectionExpanded;
  final void Function(String key, bool expanded) onSectionExpansionChanged;

  String _sectionKey(String section) => 'multi:$section';

  @override
  Widget build(BuildContext context) {
    final selectedFrames =
        shapes.whereType<FrameShape>().toList(growable: false);
    final allSelectedAreFrames =
        selectedFrames.length == shapes.length && shapes.isNotEmpty;

    return Column(
      children: [
        _buildHeader(context, 'Multiple Selection'),
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
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.select_all,
                          size: 24,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: VioSpacing.md),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${shapes.length} objects selected',
                              style: VioTypography.bodyMedium.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              _getSelectionSummary(),
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

                // Alignment tools
                VioPanel(
                  title: 'Alignment',
                  collapsible: true,
                  isExpanded: isSectionExpanded(_sectionKey('alignment')),
                  onExpansionChanged: (expanded) => onSectionExpansionChanged(
                    _sectionKey('alignment'),
                    expanded,
                  ),
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
                    collapsible: true,
                    isExpanded: isSectionExpanded(_sectionKey('frame_preset')),
                    onExpansionChanged: (expanded) => onSectionExpansionChanged(
                      _sectionKey('frame_preset'),
                      expanded,
                    ),
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
                  collapsible: true,
                  isExpanded: isSectionExpanded(_sectionKey('opacity')),
                  onExpansionChanged: (expanded) => onSectionExpansionChanged(
                    _sectionKey('opacity'),
                    expanded,
                  ),
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
    if (shapes.length < 2) return;

    final bloc = context.read<CanvasBloc>();

    // Calculate combined bounds of all selected shapes
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final shape in shapes) {
      final bounds = shape.bounds;
      if (bounds.left < minX) minX = bounds.left;
      if (bounds.top < minY) minY = bounds.top;
      if (bounds.right > maxX) maxX = bounds.right;
      if (bounds.bottom > maxY) maxY = bounds.bottom;
    }

    final selectionCenterX = (minX + maxX) / 2;
    final selectionCenterY = (minY + maxY) / 2;

    for (final shape in shapes) {
      if (shape.blocked) continue;

      final bounds = shape.bounds;
      double newX = shape.x;
      double newY = shape.y;

      // Horizontal alignment
      if (alignment == Alignment.centerLeft ||
          alignment == Alignment.topLeft ||
          alignment == Alignment.bottomLeft) {
        // Align left edges
        newX = minX;
      } else if (alignment == Alignment.center ||
          alignment == Alignment.topCenter ||
          alignment == Alignment.bottomCenter) {
        // Center horizontally
        newX = selectionCenterX - bounds.width / 2;
      } else if (alignment == Alignment.centerRight ||
          alignment == Alignment.topRight ||
          alignment == Alignment.bottomRight) {
        // Align right edges
        newX = maxX - bounds.width;
      }

      // Vertical alignment
      if (alignment == Alignment.topLeft ||
          alignment == Alignment.topCenter ||
          alignment == Alignment.topRight) {
        // Align top edges
        newY = minY;
      } else if (alignment == Alignment.centerLeft ||
          alignment == Alignment.center ||
          alignment == Alignment.centerRight) {
        // Center vertically
        newY = selectionCenterY - bounds.height / 2;
      } else if (alignment == Alignment.bottomLeft ||
          alignment == Alignment.bottomCenter ||
          alignment == Alignment.bottomRight) {
        // Align bottom edges
        newY = maxY - bounds.height;
      }

      // Only update if position changed
      if ((newX - shape.x).abs() > 0.001 || (newY - shape.y).abs() > 0.001) {
        final movedShape = shape.moveBy(newX - shape.x, newY - shape.y);
        bloc.add(ShapeUpdated(movedShape));
      }
    }
  }

  void _setAllOpacity(BuildContext context, double opacity) {
    final bloc = context.read<CanvasBloc>();
    for (final shape in shapes) {
      bloc.add(ShapeUpdated(shape.copyWith(opacity: opacity)));
    }
  }
}

/// Build panel header
Widget _buildHeader(BuildContext context, String title) {
  final cs = Theme.of(context).colorScheme;
  return Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: VioSpacing.md),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: cs.outline,
        ),
      ),
    ),
    child: Row(
      children: [
        Text(
          title,
          style: VioTypography.subtitle2.copyWith(
            color: cs.onSurface,
          ),
        ),
      ],
    ),
  );
}
