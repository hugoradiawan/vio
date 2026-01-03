import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

/// A color picker widget for selecting fill/stroke colors
class VioColorPicker extends StatefulWidget {
  const VioColorPicker({
    super.key,
    required this.color,
    required this.onColorChanged,
    this.showOpacity = true,
    this.opacity = 1.0,
    this.onOpacityChanged,
  });

  /// Current color value (ARGB int)
  final int color;

  /// Called when color changes
  final ValueChanged<int> onColorChanged;

  /// Whether to show opacity control
  final bool showOpacity;

  /// Current opacity (0.0 - 1.0)
  final double opacity;

  /// Called when opacity changes
  final ValueChanged<double>? onOpacityChanged;

  @override
  State<VioColorPicker> createState() => _VioColorPickerState();
}

class _VioColorPickerState extends State<VioColorPicker> {
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController(text: _colorToHex(widget.color));
  }

  @override
  void didUpdateWidget(VioColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color != widget.color) {
      _hexController.text = _colorToHex(widget.color);
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(int color) {
    return (color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
  }

  int _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      return int.parse('FF$hex', radix: 16);
    }
    return widget.color;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Color preview
        GestureDetector(
          onTap: _showColorPicker,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Color(widget.color),
              borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
              border: Border.all(color: VioColors.border),
            ),
          ),
        ),
        const SizedBox(width: VioSpacing.md),
        // Hex input
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
                  child: TextField(
                    controller: _hexController,
                    style: VioTypography.bodyMedium.copyWith(
                      color: VioColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onSubmitted: (value) {
                      if (value.length == 6) {
                        widget.onColorChanged(_hexToColor(value));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.showOpacity) ...[
          const SizedBox(width: VioSpacing.sm),
          SizedBox(
            width: 64,
            child: VioNumericField(
              label: '%',
              value: widget.opacity * 100,
              min: 0,
              max: 100,
              onChanged: (value) {
                widget.onOpacityChanged?.call(value / 100);
              },
            ),
          ),
        ],
      ],
    );
  }

  void _showColorPicker() {
    // TODO: Implement full color picker dialog
  }
}

/// Alignment buttons for shape alignment
class VioAlignmentButtons extends StatelessWidget {
  const VioAlignmentButtons({
    super.key,
    required this.onAlignLeft,
    required this.onAlignCenterH,
    required this.onAlignRight,
    required this.onAlignTop,
    required this.onAlignCenterV,
    required this.onAlignBottom,
  });

  final VoidCallback? onAlignLeft;
  final VoidCallback? onAlignCenterH;
  final VoidCallback? onAlignRight;
  final VoidCallback? onAlignTop;
  final VoidCallback? onAlignCenterV;
  final VoidCallback? onAlignBottom;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            VioSvgIconButton(
              assetPath: VioIcons.alignLeft,
              onPressed: onAlignLeft,
              tooltip: 'Align left',
            ),
            VioSvgIconButton(
              assetPath: VioIcons.alignHorizontalCenter,
              onPressed: onAlignCenterH,
              tooltip: 'Align center horizontally',
            ),
            VioSvgIconButton(
              assetPath: VioIcons.alignRight,
              onPressed: onAlignRight,
              tooltip: 'Align right',
            ),
          ],
        ),
        const SizedBox(height: VioSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            VioSvgIconButton(
              assetPath: VioIcons.alignTop,
              onPressed: onAlignTop,
              tooltip: 'Align top',
            ),
            VioSvgIconButton(
              assetPath: VioIcons.alignVerticalCenter,
              onPressed: onAlignCenterV,
              tooltip: 'Align center vertically',
            ),
            VioSvgIconButton(
              assetPath: VioIcons.alignBottom,
              onPressed: onAlignBottom,
              tooltip: 'Align bottom',
            ),
          ],
        ),
      ],
    );
  }
}

/// A slider with numeric input for property editing
class VioPropertySlider extends StatelessWidget {
  const VioPropertySlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 100.0,
    this.showInput = true,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final bool showInput;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (label.isNotEmpty) ...[
          SizedBox(
            width: 24,
            child: Text(
              label,
              style: VioTypography.caption.copyWith(
                color: VioColors.textSecondary,
              ),
            ),
          ),
        ],
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: VioColors.primary,
              inactiveTrackColor: VioColors.border,
              thumbColor: VioColors.primary,
              overlayColor: VioColors.primary.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        if (showInput) ...[
          const SizedBox(width: VioSpacing.sm),
          SizedBox(
            width: 56,
            child: VioNumericField(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ],
    );
  }
}

/// A toggle row with icon and label
class VioToggleRow extends StatelessWidget {
  const VioToggleRow({
    super.key,
    required this.iconAsset,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String iconAsset;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: VioSpacing.xs,
          horizontal: VioSpacing.sm,
        ),
        child: Row(
          children: [
            VioIcon(iconAsset, size: 16),
            const SizedBox(width: VioSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: VioTypography.bodyMedium.copyWith(
                  color: VioColors.textPrimary,
                ),
              ),
            ),
            Icon(
              value ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
              color: value ? VioColors.primary : VioColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
