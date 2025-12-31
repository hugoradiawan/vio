import 'package:flutter/material.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

/// Top toolbar containing tool selection and workspace actions
class TopToolbar extends StatelessWidget {
  const TopToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: VioColors.surface1,
        border: Border(
          bottom: BorderSide(
            color: VioColors.border,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo / Menu
          _buildMenuSection(),
          const Spacer(),
          // Actions
          _buildActionsSection(context),
          const SizedBox(width: VioSpacing.md),
        ],
      ),
    );
  }

  Widget _buildMenuSection() {
    return Row(
      children: [
        const SizedBox(width: VioSpacing.md),
        // Logo
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: VioColors.primary,
            borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
          ),
          child: const Center(
            child: Text(
              'V',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: VioSpacing.md),
        // File menu
        _MenuButton(
          label: 'File',
          onPressed: () {},
        ),
        _MenuButton(
          label: 'Edit',
          onPressed: () {},
        ),
        _MenuButton(
          label: 'View',
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildActionsSection(BuildContext context) {
    return Row(
      children: [
        // Share button
        VioButton(
          label: 'Share',
          variant: VioButtonVariant.ghost,
          size: VioButtonSize.small,
          leadingIcon: Icons.share_outlined,
          onPressed: () {},
        ),
        const SizedBox(width: VioSpacing.sm),
        // Export button
        VioButton(
          label: 'Export',
          size: VioButtonSize.small,
          leadingIcon: Icons.download_outlined,
          onPressed: () {},
        ),
      ],
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: VioColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: VioSpacing.sm),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: VioTypography.body2.copyWith(
          color: VioColors.textSecondary,
        ),
      ),
    );
  }
}
