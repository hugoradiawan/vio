import 'package:flutter/material.dart';

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
enum VioButtonSize { small, medium, large }

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
    required this.label,
    super.key,
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
    final cs = Theme.of(context).colorScheme;
    final isDisabled = onPressed == null || isLoading;

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: _getHeight(),
      child: _buildButton(isDisabled, cs),
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

  Widget _buildButton(bool isDisabled, ColorScheme cs) {
    return switch (variant) {
      VioButtonVariant.primary => _buildPrimaryButton(isDisabled, cs),
      VioButtonVariant.secondary => _buildSecondaryButton(isDisabled, cs),
      VioButtonVariant.ghost => _buildGhostButton(isDisabled, cs),
      VioButtonVariant.danger => _buildDangerButton(isDisabled, cs),
    };
  }

  Widget _buildPrimaryButton(bool isDisabled, ColorScheme cs) {
    return ElevatedButton(
      onPressed: isDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        disabledBackgroundColor: cs.primary.withValues(alpha: 0.5),
        disabledForegroundColor: cs.onPrimary,
        padding: _getPadding(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
        ),
      ),
      child: _buildContent(cs.onPrimary),
    );
  }

  Widget _buildSecondaryButton(bool isDisabled, ColorScheme cs) {
    return OutlinedButton(
      onPressed: isDisabled ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.onSurface,
        side: BorderSide(
          color: isDisabled ? cs.outlineVariant : cs.outline,
        ),
        padding: _getPadding(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
        ),
      ),
      child: _buildContent(
        isDisabled ? cs.onSurface.withValues(alpha: 0.38) : cs.onSurface,
      ),
    );
  }

  Widget _buildGhostButton(bool isDisabled, ColorScheme cs) {
    return TextButton(
      onPressed: isDisabled ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: cs.onSurfaceVariant,
        padding: _getPadding(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
        ),
      ),
      child: _buildContent(
        isDisabled ? cs.onSurface.withValues(alpha: 0.38) : cs.onSurfaceVariant,
      ),
    );
  }

  Widget _buildDangerButton(bool isDisabled, ColorScheme cs) {
    return ElevatedButton(
      onPressed: isDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: cs.error,
        foregroundColor: cs.onError,
        disabledBackgroundColor: cs.errorContainer,
        padding: _getPadding(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
        ),
      ),
      child: _buildContent(cs.onError),
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
      children.add(
        Icon(
          leadingIcon,
          size: _getIconSize(),
          color: color,
        ),
      );
      children.add(const SizedBox(width: VioSpacing.xs));
    }

    children.add(Text(label, style: _getTextStyle().copyWith(color: color)));

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
