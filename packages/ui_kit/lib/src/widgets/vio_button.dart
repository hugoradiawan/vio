import 'package:flutter/material.dart';

import '../theme/vio_colors.dart';
import '../theme/vio_spacing.dart';
import '../theme/vio_typography.dart';

/// Button variants
enum VioButtonVariant {
  /// Primary filled button
  primary,

  /// Secondary/outline button
  secondary,

  /// Ghost/text button
  ghost,

  /// Danger/destructive button
  danger,
}

/// Button sizes
enum VioButtonSize {
  small,
  medium,
  large,
}

/// Vio Design System Button
class VioButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final VioButtonVariant variant;
  final VioButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool isFullWidth;

  const VioButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = VioButtonVariant.primary,
    this.size = VioButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: _getHeight(),
      child: _buildButton(isDisabled),
    );
  }

  double _getHeight() {
    return switch (size) {
      VioButtonSize.small => 28,
      VioButtonSize.medium => 36,
      VioButtonSize.large => 44,
    };
  }

  EdgeInsets _getPadding() {
    return switch (size) {
      VioButtonSize.small => const EdgeInsets.symmetric(horizontal: 12),
      VioButtonSize.medium => const EdgeInsets.symmetric(horizontal: 16),
      VioButtonSize.large => const EdgeInsets.symmetric(horizontal: 20),
    };
  }

  double _getIconSize() {
    return switch (size) {
      VioButtonSize.small => 14,
      VioButtonSize.medium => 16,
      VioButtonSize.large => 18,
    };
  }

  TextStyle _getTextStyle() {
    return switch (size) {
      VioButtonSize.small => VioTypography.labelSmall,
      VioButtonSize.medium => VioTypography.button,
      VioButtonSize.large => VioTypography.labelLarge,
    };
  }

  Widget _buildButton(bool isDisabled) {
    return switch (variant) {
      VioButtonVariant.primary => _buildPrimaryButton(isDisabled),
      VioButtonVariant.secondary => _buildSecondaryButton(isDisabled),
      VioButtonVariant.ghost => _buildGhostButton(isDisabled),
      VioButtonVariant.danger => _buildDangerButton(isDisabled),
    };
  }

  Widget _buildPrimaryButton(bool isDisabled) {
    return ElevatedButton(
      onPressed: isDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: VioColors.primary,
        foregroundColor: VioColors.background,
        disabledBackgroundColor: VioColors.primary50,
        disabledForegroundColor: VioColors.background,
        padding: _getPadding(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
        ),
      ),
      child: _buildContent(VioColors.background),
    );
  }

  Widget _buildSecondaryButton(bool isDisabled) {
    return OutlinedButton(
      onPressed: isDisabled ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: VioColors.textPrimary,
        side: BorderSide(
          color: isDisabled ? VioColors.borderSubtle : VioColors.border,
        ),
        padding: _getPadding(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
        ),
      ),
      child: _buildContent(
        isDisabled ? VioColors.textDisabled : VioColors.textPrimary,
      ),
    );
  }

  Widget _buildGhostButton(bool isDisabled) {
    return TextButton(
      onPressed: isDisabled ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: VioColors.textSecondary,
        padding: _getPadding(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
        ),
      ),
      child: _buildContent(
        isDisabled ? VioColors.textDisabled : VioColors.textSecondary,
      ),
    );
  }

  Widget _buildDangerButton(bool isDisabled) {
    return ElevatedButton(
      onPressed: isDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: VioColors.error,
        foregroundColor: VioColors.textPrimary,
        disabledBackgroundColor: VioColors.errorSubtle,
        padding: _getPadding(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
        ),
      ),
      child: _buildContent(VioColors.textPrimary),
    );
  }

  Widget _buildContent(Color color) {
    if (isLoading) {
      return SizedBox(
        width: _getIconSize(),
        height: _getIconSize(),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      );
    }

    final children = <Widget>[];

    if (leadingIcon != null) {
      children.add(Icon(leadingIcon, size: _getIconSize()));
      children.add(const SizedBox(width: VioSpacing.xs));
    }

    children.add(
      Text(label, style: _getTextStyle().copyWith(color: color)),
    );

    if (trailingIcon != null) {
      children.add(const SizedBox(width: VioSpacing.xs));
      children.add(Icon(trailingIcon, size: _getIconSize()));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }
}
