import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_core/vio_core.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../bloc/canvas_bloc.dart';

/// A single layer item in the layers panel
class LayerItem extends StatefulWidget {
  const LayerItem({
    required this.shape,
    required this.depth,
    required this.isExpanded,
    required this.hasChildren,
    required this.isSelected,
    required this.isHovered,
    super.key,
  });

  final Shape shape;
  final int depth;
  final bool isExpanded;
  final bool hasChildren;
  final bool isSelected;
  final bool isHovered;

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
        child: Container(
          height: 32,
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            border: widget.isHovered && !widget.isSelected
                ? Border.all(
                    color: VioColors.primary.withValues(alpha: 0.5),
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
              _buildVisibilityButton(),
              // Lock toggle
              _buildLockButton(),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (widget.isSelected) {
      return VioColors.primary.withValues(alpha: 0.2);
    }
    return Colors.transparent;
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
        icon: Icon(
          widget.isExpanded ? Icons.expand_more : Icons.chevron_right,
          color: VioColors.textSecondary,
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
          ? VioColors.textDisabled
          : VioColors.textSecondary,
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
          style: const TextStyle(
            fontSize: 12,
            color: VioColors.textPrimary,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 4,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: VioColors.primary),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: VioColors.primary, width: 2),
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
            ? VioColors.textDisabled
            : VioColors.textPrimary,
        fontStyle: widget.shape.hidden ? FontStyle.italic : FontStyle.normal,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildVisibilityButton() {
    return SizedBox(
      width: 24,
      height: 24,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 14,
        icon: Icon(
          widget.shape.hidden ? Icons.visibility_off : Icons.visibility,
          color: widget.shape.hidden
              ? VioColors.textDisabled
              : VioColors.textSecondary,
        ),
        onPressed: () {
          context
              .read<CanvasBloc>()
              .add(ShapeVisibilityToggled(widget.shape.id));
        },
      ),
    );
  }

  Widget _buildLockButton() {
    return SizedBox(
      width: 24,
      height: 24,
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
    );
  }

  void _handleTap(BuildContext context) {
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final isCtrlPressed = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    context.read<CanvasBloc>().add(
          ShapeSelected(
            widget.shape.id,
            addToSelection: isShiftPressed || isCtrlPressed,
          ),
        );
  }
}
