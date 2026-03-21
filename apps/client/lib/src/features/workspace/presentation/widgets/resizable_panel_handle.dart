import 'package:flutter/material.dart';

/// A vertical drag handle for resizing side panels.
///
/// Features:
/// - Cursor change on hover (resize column)
/// - Visual feedback when dragging
/// - Double-click to reset to default width
/// - Configurable for left or right side panels
class ResizablePanelHandle extends StatefulWidget {
  const ResizablePanelHandle({
    required this.onDragUpdate,
    super.key,
    this.onDragEnd,
    this.onDoubleTap,
    this.isLeftSide = true,
  });

  /// Called during drag with the horizontal delta.
  /// For left-side handles (right edge of left panel), positive delta = wider.
  /// For right-side handles (left edge of right panel), positive delta = narrower.
  final void Function(double delta) onDragUpdate;

  /// Called when drag ends.
  final VoidCallback? onDragEnd;

  /// Called on double-tap to reset width.
  final VoidCallback? onDoubleTap;

  /// Whether this handle is on the left side of a panel.
  /// - true: Handle is on the right edge of the left panel
  /// - false: Handle is on the left edge of the right panel
  final bool isLeftSide;

  @override
  State<ResizablePanelHandle> createState() => _ResizablePanelHandleState();
}

class _ResizablePanelHandleState extends State<ResizablePanelHandle> {
  bool _isHovered = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final isActive = _isHovered || _isDragging;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onHorizontalDragStart: (_) {
          setState(() => _isDragging = true);
        },
        onHorizontalDragUpdate: (details) {
          widget.onDragUpdate(details.delta.dx);
        },
        onHorizontalDragEnd: (_) {
          setState(() => _isDragging = false);
          widget.onDragEnd?.call();
        },
        onDoubleTap: widget.onDoubleTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 1,
              color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
            ),
        ),
      ),
    );
  }
}
