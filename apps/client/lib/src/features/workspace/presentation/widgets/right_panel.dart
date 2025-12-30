import 'package:flutter/material.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

/// Right panel containing properties inspector for selected shapes
class RightPanel extends StatelessWidget {
  const RightPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: VioColors.surface1,
        border: Border(
          left: BorderSide(
            color: VioColors.border,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: VioSpacing.md),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: VioColors.border,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Design',
                  style: VioTypography.subtitle2.copyWith(
                    color: VioColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Properties
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Position & Size
                  const VioPanel(
                    title: 'Position',
                    child: _PositionSection(),
                  ),

                  // Fill
                  VioPanel(
                    title: 'Fill',
                    trailing: VioIconButton(
                      icon: Icons.add,
                      size: 24,
                      onPressed: () {},
                    ),
                    child: const _FillSection(),
                  ),

                  // Stroke
                  VioPanel(
                    title: 'Stroke',
                    trailing: VioIconButton(
                      icon: Icons.add,
                      size: 24,
                      onPressed: () {},
                    ),
                    child: const _StrokeSection(),
                  ),

                  // Shadow
                  VioPanel(
                    title: 'Shadow',
                    trailing: VioIconButton(
                      icon: Icons.add,
                      size: 24,
                      onPressed: () {},
                    ),
                    child: const _ShadowSection(),
                  ),

                  // Blur
                  VioPanel(
                    title: 'Blur',
                    trailing: VioIconButton(
                      icon: Icons.add,
                      size: 24,
                      onPressed: () {},
                    ),
                    child: const _BlurSection(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionSection extends StatelessWidget {
  const _PositionSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(VioSpacing.sm),
      child: Column(
        children: [
          // X, Y
          Row(
            children: [
              Expanded(
                child: VioNumericField(
                  label: 'X',
                  value: 0,
                  onChanged: (value) {},
                ),
              ),
              const SizedBox(width: VioSpacing.sm),
              Expanded(
                child: VioNumericField(
                  label: 'Y',
                  value: 0,
                  onChanged: (value) {},
                ),
              ),
            ],
          ),
          const SizedBox(height: VioSpacing.sm),
          // W, H
          Row(
            children: [
              Expanded(
                child: VioNumericField(
                  label: 'W',
                  value: 100,
                  onChanged: (value) {},
                ),
              ),
              const SizedBox(width: VioSpacing.sm),
              Expanded(
                child: VioNumericField(
                  label: 'H',
                  value: 100,
                  onChanged: (value) {},
                ),
              ),
            ],
          ),
          const SizedBox(height: VioSpacing.sm),
          // Rotation, Corner radius
          Row(
            children: [
              Expanded(
                child: VioNumericField(
                  label: '°',
                  value: 0,
                  onChanged: (value) {},
                ),
              ),
              const SizedBox(width: VioSpacing.sm),
              Expanded(
                child: VioNumericField(
                  label: 'R',
                  value: 0,
                  onChanged: (value) {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FillSection extends StatelessWidget {
  const _FillSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(VioSpacing.sm),
      child: Row(
        children: [
          // Color preview
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: VioColors.primary,
              borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
              border: Border.all(
                color: VioColors.border,
              ),
            ),
          ),
          const SizedBox(width: VioSpacing.md),
          // Color value
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: VioSpacing.sm),
              decoration: BoxDecoration(
                color: VioColors.surfaceElevated,
                borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
                border: Border.all(color: VioColors.border),
              ),
              child: Row(
                children: [
                  Text(
                    '#',
                    style: VioTypography.bodyMedium.copyWith(
                      color: VioColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '4C9AFF',
                      style: VioTypography.bodyMedium.copyWith(
                        color: VioColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: VioSpacing.sm),
          // Opacity
          SizedBox(
            width: 64,
            child: VioNumericField(
              label: '%',
              value: 100,
              onChanged: (value) {},
            ),
          ),
        ],
      ),
    );
  }
}

class _StrokeSection extends StatelessWidget {
  const _StrokeSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(VioSpacing.sm),
      child: Center(
        child: Text(
          'No stroke',
          style: VioTypography.caption.copyWith(
            color: VioColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _ShadowSection extends StatelessWidget {
  const _ShadowSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(VioSpacing.sm),
      child: Center(
        child: Text(
          'No shadow',
          style: VioTypography.caption.copyWith(
            color: VioColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _BlurSection extends StatelessWidget {
  const _BlurSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(VioSpacing.sm),
      child: Center(
        child: Text(
          'No blur',
          style: VioTypography.caption.copyWith(
            color: VioColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
