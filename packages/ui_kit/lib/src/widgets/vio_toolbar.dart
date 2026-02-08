import 'package:flutter/material.dart';

import '../theme/vio_colors.dart';
import '../theme/vio_spacing.dart';
import 'vio_icon_button.dart';

/// Vio Design System Toolbar
class VioToolbar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? leading;
  final Widget? title;
  final List<Widget>? actions;
  final bool showDivider;
  final double height;

  const VioToolbar({
    super.key,
    this.leading,
    this.title,
    this.actions,
    this.showDivider = true,
    this.height = VioSpacing.toolbarHeight,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: VioColors.surface,
        border: showDivider
            ? const Border(bottom: BorderSide(color: VioColors.border))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: VioSpacing.sm),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: VioSpacing.sm),
          ],
          if (title != null) Expanded(child: title!),
          if (actions != null) ...[
            const SizedBox(width: VioSpacing.sm),
            ...actions!,
          ],
        ],
      ),
    );
  }
}

/// Toolbar button group with separators
class VioToolbarGroup extends StatelessWidget {
  final List<Widget> children;
  final bool showSeparators;

  const VioToolbarGroup({
    required this.children,
    super.key,
    this.showSeparators = true,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    if (!showSeparators) {
      return Row(mainAxisSize: MainAxisSize.min, children: children);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1) const VioToolbarSeparator(),
        ],
      ],
    );
  }
}

/// Vertical separator for toolbar
class VioToolbarSeparator extends StatelessWidget {
  const VioToolbarSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: VioSpacing.xs),
      color: VioColors.border,
    );
  }
}

/// Toolbar item for common tool buttons
class VioToolbarItem extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final bool isSelected;
  final VoidCallback? onPressed;

  const VioToolbarItem({
    required this.icon,
    super.key,
    this.tooltip,
    this.isSelected = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return VioIconButton(
      icon: icon,
      tooltip: tooltip,
      isSelected: isSelected,
      onPressed: onPressed,
      size: 32,
      iconSize: 18,
    );
  }
}

/// Horizontal toolbar for the canvas workspace
class VioCanvasToolbar extends StatelessWidget {
  final List<ToolbarToolItem> tools;
  final String? selectedToolId;
  final ValueChanged<String>? onToolSelected;

  const VioCanvasToolbar({
    required this.tools,
    super.key,
    this.selectedToolId,
    this.onToolSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VioColors.surface,
        borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
        border: Border.all(color: VioColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(VioSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < tools.length; i++) ...[
            _buildToolButton(tools[i]),
            if (i < tools.length - 1 && tools[i].showSeparatorAfter)
              const VioToolbarSeparator(),
          ],
        ],
      ),
    );
  }

  Widget _buildToolButton(ToolbarToolItem tool) {
    return VioToolbarItem(
      icon: tool.icon,
      tooltip: tool.tooltip,
      isSelected: selectedToolId == tool.id,
      onPressed: () => onToolSelected?.call(tool.id),
    );
  }
}

/// Tool item data for toolbar
class ToolbarToolItem {
  final String id;
  final IconData icon;
  final String? tooltip;
  final bool showSeparatorAfter;

  const ToolbarToolItem({
    required this.id,
    required this.icon,
    this.tooltip,
    this.showSeparatorAfter = false,
  });
}
