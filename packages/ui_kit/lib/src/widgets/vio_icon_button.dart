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
    required this.icon,
    super.key,
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
    final cs = Theme.of(context).colorScheme;
    final buttonSize = size ?? VioSpacing.iconButtonSize;
    final actualIconSize = iconSize ?? VioSpacing.iconMd;
    final isDisabled = onPressed == null;

    Widget button = SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: _buildButton(buttonSize, actualIconSize, isDisabled, cs),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip, child: button);
    }

    return button;
  }

  Widget _buildButton(
    double size,
    double iconSize,
    bool isDisabled,
    ColorScheme cs,
  ) {
    return switch (variant) {
      VioIconButtonVariant.ghost => _buildGhostButton(iconSize, isDisabled, cs),
      VioIconButtonVariant.filled => _buildFilledButton(
        iconSize,
        isDisabled,
        cs,
      ),
      VioIconButtonVariant.outlined => _buildOutlinedButton(
        iconSize,
        isDisabled,
        cs,
      ),
    };
  }

  Widget _buildGhostButton(double iconSize, bool isDisabled, ColorScheme cs) {
    final iconColor = _getIconColor(isDisabled, cs);
    final bgColor = isSelected ? cs.primaryContainer : Colors.transparent;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
      child: InkWell(
        onTap: isDisabled ? null : onPressed,
        borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
        hoverColor: VioColors.hoverOverlay,
        splashColor: VioColors.pressedOverlay,
        child: Center(
          child: Icon(icon, size: iconSize, color: iconColor),
        ),
      ),
    );
  }

  Widget _buildFilledButton(double iconSize, bool isDisabled, ColorScheme cs) {
    final iconColor = isDisabled
        ? cs.onSurface.withValues(alpha: 0.38)
        : cs.onPrimary;
    final bgColor = isDisabled ? cs.surfaceContainerHigh : cs.primary;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
      child: InkWell(
        onTap: isDisabled ? null : onPressed,
        borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
        hoverColor: VioColors.hoverOverlay,
        splashColor: VioColors.pressedOverlay,
        child: Center(
          child: Icon(icon, size: iconSize, color: iconColor),
        ),
      ),
    );
  }

  Widget _buildOutlinedButton(
    double iconSize,
    bool isDisabled,
    ColorScheme cs,
  ) {
    final iconColor = _getIconColor(isDisabled, cs);
    final borderColor = isSelected ? cs.primary : cs.outline;

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
            child: Icon(icon, size: iconSize, color: iconColor),
          ),
        ),
      ),
    );
  }

  Color _getIconColor(bool isDisabled, ColorScheme cs) {
    if (color != null) return color!;
    if (isDisabled) return cs.onSurface.withValues(alpha: 0.38);
    if (isSelected) return cs.primary;
    return cs.onSurfaceVariant;
  }
}
