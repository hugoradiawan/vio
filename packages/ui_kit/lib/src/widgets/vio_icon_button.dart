import 'package:flutter/material.dart';

import '../theme/vio_colors.dart';
import '../theme/vio_spacing.dart';

/// Icon button variants
enum VioIconButtonVariant {
  /// Default ghost style
  ghost,

  /// Filled style
  filled,

  /// Outlined style
  outlined,
}

/// Vio Design System Icon Button
class VioIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final VioIconButtonVariant variant;
  final double? size;
  final double? iconSize;
  final String? tooltip;
  final bool isSelected;
  final Color? color;

  const VioIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.variant = VioIconButtonVariant.ghost,
    this.size,
    this.iconSize,
    this.tooltip,
    this.isSelected = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final buttonSize = size ?? VioSpacing.iconButtonSize;
    final actualIconSize = iconSize ?? VioSpacing.iconMd;
    final isDisabled = onPressed == null;

    Widget button = SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: _buildButton(buttonSize, actualIconSize, isDisabled),
    );

    if (tooltip != null) {
      button = Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }

  Widget _buildButton(double size, double iconSize, bool isDisabled) {
    return switch (variant) {
      VioIconButtonVariant.ghost => _buildGhostButton(iconSize, isDisabled),
      VioIconButtonVariant.filled => _buildFilledButton(iconSize, isDisabled),
      VioIconButtonVariant.outlined =>
        _buildOutlinedButton(iconSize, isDisabled),
    };
  }

  Widget _buildGhostButton(double iconSize, bool isDisabled) {
    final iconColor = _getIconColor(isDisabled);
    final bgColor = isSelected ? VioColors.primary10 : Colors.transparent;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
      child: InkWell(
        onTap: isDisabled ? null : onPressed,
        borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
        hoverColor: VioColors.hoverOverlay,
        splashColor: VioColors.pressedOverlay,
        child: Center(
          child: Icon(
            icon,
            size: iconSize,
            color: iconColor,
          ),
        ),
      ),
    );
  }

  Widget _buildFilledButton(double iconSize, bool isDisabled) {
    final iconColor =
        isDisabled ? VioColors.textDisabled : VioColors.background;
    final bgColor = isSelected
        ? VioColors.primary
        : (isDisabled ? VioColors.surfaceElevated : VioColors.primary);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
      child: InkWell(
        onTap: isDisabled ? null : onPressed,
        borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
        hoverColor: VioColors.hoverOverlay,
        splashColor: VioColors.pressedOverlay,
        child: Center(
          child: Icon(
            icon,
            size: iconSize,
            color: iconColor,
          ),
        ),
      ),
    );
  }

  Widget _buildOutlinedButton(double iconSize, bool isDisabled) {
    final iconColor = _getIconColor(isDisabled);
    final borderColor = isSelected ? VioColors.primary : VioColors.border;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
        child: InkWell(
          onTap: isDisabled ? null : onPressed,
          borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
          hoverColor: VioColors.hoverOverlay,
          splashColor: VioColors.pressedOverlay,
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }

  Color _getIconColor(bool isDisabled) {
    if (color != null) return color!;
    if (isDisabled) return VioColors.textDisabled;
    if (isSelected) return VioColors.primary;
    return VioColors.textSecondary;
  }
}
