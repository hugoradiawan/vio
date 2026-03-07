import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_core/vio_core.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../../core/platform_shortcuts.dart';
import '../../bloc/canvas_bloc.dart';

enum _LayerContextAction {
  cut,
  copy,
  paste,
  group,
  ungroup,
  bringToFront,
  sendToBack,
}

/// A single layer item in the layers panel
class LayerItem extends StatefulWidget {
  const LayerItem({
    required this.shape,
    required this.depth,
    required this.isExpanded,
    required this.hasChildren,
    required this.isSelected,
    required this.isHovered,
    required this.isRowHovered,
    super.key,
  });

  final Shape shape;
  final int depth;
  final bool isExpanded;
  final bool hasChildren;
  final bool isSelected;
  final bool isHovered;
  final bool isRowHovered;

  @override
  State<LayerItem> createState() => _LayerItemState();
}

class _LayerItemState extends State<LayerItem> {
  bool _isEditing = false;
  late TextEditingController _nameController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.shape.name);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shape.name != widget.shape.name && !_isEditing) {
      _nameController.text = widget.shape.name;
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      _submitName();
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _nameController.text = widget.shape.name;
      _nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nameController.text.length,
      );
    });
    Future.microtask(() => _focusNode.requestFocus());
  }

  void _submitName() {
    if (_isEditing) {
      final newName = _nameController.text.trim();
      if (newName.isNotEmpty && newName != widget.shape.name) {
        context.read<CanvasBloc>().add(ShapeRenamed(widget.shape.id, newName));
      }
      setState(() => _isEditing = false);
    }
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _nameController.text = widget.shape.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final indent = widget.depth * 16.0;
    final isCanvasLinkedHover = widget.isHovered && !widget.isRowHovered;
    final isHighlighted =
        widget.isSelected || widget.isRowHovered || isCanvasLinkedHover;
    final showLeftAccent = widget.isSelected || isCanvasLinkedHover;

    final showControlsOnHover = widget.isRowHovered;
    final showVisibilityControl = showControlsOnHover || widget.shape.hidden;
    final showLockControl = showControlsOnHover || widget.shape.blocked;

    return MouseRegion(
      onEnter: (_) {
        context.read<CanvasBloc>().add(LayerHovered(widget.shape.id));
      },
      onExit: (_) {
        context.read<CanvasBloc>().add(const LayerHovered(null));
      },
      child: GestureDetector(
        onTap: () => _handleTap(context),
        onDoubleTap: _startEditing,
        onSecondaryTapDown: (details) => _handleSecondaryTapDown(
          context,
          details.globalPosition,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          height: 32,
          decoration: BoxDecoration(
            color:
                isHighlighted ? Theme.of(context).colorScheme.surfaceContainerHigh : Colors.transparent,
            border: showLeftAccent
                ? Border(
                    left: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              SizedBox(width: indent + 4),
              // Expand/collapse button
              _buildExpandButton(),
              const SizedBox(width: 4),
              // Type icon
              _buildTypeIcon(),
              const SizedBox(width: 8),
              // Name
              Expanded(child: _buildName()),
              // Visibility toggle
              _buildVisibilityButton(visible: showVisibilityControl),
              // Lock toggle
              _buildLockButton(visible: showLockControl),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSecondaryTapDown(
    BuildContext context,
    Offset globalPosition,
  ) async {
    if (!context.mounted) return;

    final bloc = context.read<CanvasBloc>();
    final state = bloc.state;

    final selectionIds = state.selectedShapeIds.contains(widget.shape.id)
        ? state.selectedShapeIds
        : <String>[widget.shape.id];

    // Select-under-cursor always.
    if (!state.selectedShapeIds.contains(widget.shape.id)) {
      bloc.add(ShapesSelected([widget.shape.id]));
    }

    final selectedShapes = selectionIds
        .map((id) => state.shapes[id])
        .whereType<Shape>()
        .toList(growable: false);

    final hasSelection = selectedShapes.isNotEmpty;
    final hasClipboard = state.clipboardShapes.isNotEmpty;
    final hasUnlockedSelection = selectedShapes.any((s) => !s.blocked);

    final canGroup = () {
      if (selectedShapes.length < 2) return false;
      final groupable = selectedShapes
          .where((s) => s is! FrameShape)
          .where((s) => !s.blocked)
          .toList(growable: false);
      if (groupable.length < 2) return false;
      final frameIds = groupable.map((s) => s.frameId).toSet();
      return frameIds.length <= 1;
    }();

    final canUngroup = selectedShapes.any(
      (s) => s is GroupShape && !s.blocked,
    );

    const menuItemHeight = 34.0;
    const menuItemPadding = EdgeInsets.symmetric(horizontal: 12);
    const menuTextStyle = TextStyle(fontSize: 13);

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final action = await showMenu<_LayerContextAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: <PopupMenuEntry<_LayerContextAction>>[
        PopupMenuItem(
          value: _LayerContextAction.cut,
          enabled: hasSelection && hasUnlockedSelection,
          height: menuItemHeight,
          padding: menuItemPadding,
          textStyle: menuTextStyle,
          child: const Text('Cut'),
        ),
        PopupMenuItem(
          value: _LayerContextAction.copy,
          enabled: hasSelection,
          height: menuItemHeight,
          padding: menuItemPadding,
          textStyle: menuTextStyle,
          child: const Text('Copy'),
        ),
        PopupMenuItem(
          value: _LayerContextAction.paste,
          enabled: hasClipboard,
          height: menuItemHeight,
          padding: menuItemPadding,
          textStyle: menuTextStyle,
          child: const Text('Paste'),
        ),
        const PopupMenuDivider(height: 8),
        PopupMenuItem(
          value: _LayerContextAction.group,
          enabled: canGroup,
          height: menuItemHeight,
          padding: menuItemPadding,
          textStyle: menuTextStyle,
          child: const Text('Group'),
        ),
        PopupMenuItem(
          value: _LayerContextAction.ungroup,
          enabled: canUngroup,
          height: menuItemHeight,
          padding: menuItemPadding,
          textStyle: menuTextStyle,
          child: const Text('Ungroup'),
        ),
        const PopupMenuDivider(height: 8),
        PopupMenuItem(
          value: _LayerContextAction.bringToFront,
          enabled: hasSelection && hasUnlockedSelection,
          height: menuItemHeight,
          padding: menuItemPadding,
          textStyle: menuTextStyle,
          child: const Text('Bring to front'),
        ),
        PopupMenuItem(
          value: _LayerContextAction.sendToBack,
          enabled: hasSelection && hasUnlockedSelection,
          height: menuItemHeight,
          padding: menuItemPadding,
          textStyle: menuTextStyle,
          child: const Text('Send to back'),
        ),
      ],
    );

    if (!context.mounted || action == null) return;

    switch (action) {
      case _LayerContextAction.cut:
        bloc.add(const CutSelected());
        break;
      case _LayerContextAction.copy:
        bloc.add(const CopySelected());
        break;
      case _LayerContextAction.paste:
        bloc.add(const PasteShapes());
        break;
      case _LayerContextAction.group:
        bloc.add(const CreateGroupFromSelection());
        break;
      case _LayerContextAction.ungroup:
        bloc.add(const UngroupSelected());
        break;
      case _LayerContextAction.bringToFront:
        bloc.add(const BringToFrontSelected());
        break;
      case _LayerContextAction.sendToBack:
        bloc.add(const SendToBackSelected());
        break;
    }
  }

  Widget _buildExpandButton() {
    if (!widget.hasChildren) {
      return const SizedBox(width: 20);
    }

    return SizedBox(
      width: 20,
      height: 20,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 16,
        icon: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: widget.isExpanded ? 0.5 : 0.0),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          builder: (context, turns, child) {
            return Transform.rotate(
              angle: turns * 3.1415926535897932,
              child: child,
            );
          },
          child: const Icon(
            Icons.expand_more,
          ),
        ),
        onPressed: () {
          final bloc = context.read<CanvasBloc>();
          if (widget.isExpanded) {
            bloc.add(LayerCollapsed(widget.shape.id));
          } else {
            bloc.add(LayerExpanded(widget.shape.id));
          }
        },
      ),
    );
  }

  Widget _buildTypeIcon() {
    return Icon(
      _getShapeIcon(),
      size: 16,
      color: widget.shape.hidden
          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)
          : Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  IconData _getShapeIcon() {
    return switch (widget.shape.type) {
      ShapeType.frame => Icons.dashboard_outlined,
      ShapeType.group => Icons.folder_outlined,
      ShapeType.rectangle => Icons.rectangle_outlined,
      ShapeType.ellipse => Icons.circle_outlined,
      ShapeType.path => Icons.gesture,
      ShapeType.text => Icons.text_fields,
      ShapeType.image => Icons.image_outlined,
      ShapeType.svg => Icons.code,
      ShapeType.bool => Icons.layers_outlined,
    };
  }

  Widget _buildName() {
    if (_isEditing) {
      return KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.enter) {
              _submitName();
            } else if (event.logicalKey == LogicalKeyboardKey.escape) {
              _cancelEditing();
            }
          }
        },
        child: TextField(
          controller: _nameController,
          focusNode: _focusNode,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 4,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
            ),
          ),
          onSubmitted: (_) => _submitName(),
        ),
      );
    }

    return Text(
      widget.shape.name,
      style: TextStyle(
        fontSize: 12,
        color: widget.shape.hidden
            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)
            : Theme.of(context).colorScheme.onSurface,
        fontStyle: widget.shape.hidden ? FontStyle.italic : FontStyle.normal,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _fadeControl({required bool visible, required Widget child}) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }

  Widget _buildVisibilityButton({required bool visible}) {
    return SizedBox(
      width: 24,
      height: 24,
      child: _fadeControl(
        visible: visible,
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: 14,
          icon: Icon(
            widget.shape.hidden ? Icons.visibility_off : Icons.visibility,
            color: widget.shape.hidden
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          onPressed: () {
            context
                .read<CanvasBloc>()
                .add(ShapeVisibilityToggled(widget.shape.id));
          },
        ),
      ),
    );
  }

  Widget _buildLockButton({required bool visible}) {
    return SizedBox(
      width: 24,
      height: 24,
      child: _fadeControl(
        visible: visible,
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: 14,
          icon: Icon(
            widget.shape.blocked ? Icons.lock : Icons.lock_open,
            color: widget.shape.blocked
                ? VioColors.warning
                : VioColors.textSecondary,
          ),
          onPressed: () {
            context.read<CanvasBloc>().add(ShapeLockToggled(widget.shape.id));
          },
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final isCtrlPressed = isPlatformModifierPressed();

    context.read<CanvasBloc>().add(
          ShapeSelected(
            widget.shape.id,
            addToSelection: isShiftPressed || isCtrlPressed,
          ),
        );
  }
}
