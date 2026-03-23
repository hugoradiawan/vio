import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

/// Settings section for choosing the app theme.
///
/// Shows the current seed color, a grid of preset swatches, a custom color
/// picker button, and a theme-mode selector (dark / light / system).
///
/// Callbacks [onSeedChanged] and [onModeChanged] are fired when the user
/// makes a selection so the caller can relay the events to [ThemeBloc] and
/// persist the new value.
class ThemeSection extends StatelessWidget {
  const ThemeSection({
    required this.onSeedChanged,
    required this.onModeChanged,
    super.key,
  });

  final ValueChanged<Color> onSeedChanged;
  final ValueChanged<ThemeMode> onModeChanged;

  // Curated quick-access seed presets — uses the Vio collaboration colour
  // palette so they're already brand-approved, plus a dedicated "Vio default"
  // entry that exactly reproduces the original fixed blue theme.
  static const List<({String label, Color color})> _presets = [
    (label: 'Vio', color: VioColors.primary),
    (label: 'Red', color: Color(0xFFFF6B6B)),
    (label: 'Teal', color: Color(0xFF4ECDC4)),
    (label: 'Yellow', color: Color(0xFFFFE66D)),
    (label: 'Mint', color: Color(0xFF95E1D3)),
    (label: 'Coral', color: Color(0xFFF38181)),
    (label: 'Purple', color: Color(0xFFAA96DA)),
    (label: 'Pink', color: Color(0xFFFCBAD3)),
    (label: 'Sky', color: Color(0xFFA8D8EA)),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, state) {
        final cs = Theme.of(context).colorScheme;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: VioSpacing.md),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
            border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // — Seed color label ——————————————————————————————————————
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  VioSpacing.md,
                  VioSpacing.md,
                  VioSpacing.md,
                  VioSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: VioSpacing.xs),
                    Text(
                      'Accent Color',
                      style: VioTypography.labelMedium.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    // Current seed preview chip
                    _ColorChip(
                      color: state.seedColor,
                      isSelected: false,
                      size: 20,
                    ),
                  ],
                ),
              ),

              // — Preset swatch grid ————————————————————————————————————
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: VioSpacing.md),
                child: Wrap(
                  spacing: VioSpacing.sm,
                  runSpacing: VioSpacing.sm,
                  children: [
                    for (final preset in _presets)
                      _ColorChip(
                        color: preset.color,
                        label: preset.label,
                        isSelected: state.seedColor.toARGB32() ==
                            preset.color.toARGB32(),
                        onTap: () => onSeedChanged(preset.color),
                      ),
                    // Custom picker button
                    _CustomColorButton(
                      currentColor: state.seedColor,
                      onColorPicked: onSeedChanged,
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: VioSpacing.md),
                child: Divider(
                  height: VioSpacing.xl,
                  color: cs.outline.withValues(alpha: 0.25),
                ),
              ),

              // — Theme mode selector ——————————————————————————————————
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  VioSpacing.md,
                  0,
                  VioSpacing.md,
                  VioSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.brightness_6_outlined,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: VioSpacing.xs),
                        Text(
                          'Brightness',
                          style: VioTypography.labelMedium.copyWith(
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: VioSpacing.sm),
                    _ThemeModeSelector(
                      currentMode: state.themeMode,
                      onChanged: onModeChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Internal widgets
// ---------------------------------------------------------------------------

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.color,
    required this.isSelected,
    this.label,
    this.onTap,
    this.size = 32,
  });

  final Color color;
  final bool isSelected;
  final String? label;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: label ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: isSelected
                ? Border.all(color: cs.onSurface, width: 2.5)
                : Border.all(color: cs.outlineVariant),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: isSelected
              ? const Icon(Icons.check, color: Colors.white, size: 14)
              : null,
        ),
      ),
    );
  }
}

class _CustomColorButton extends StatelessWidget {
  const _CustomColorButton({
    required this.currentColor,
    required this.onColorPicked,
  });

  final Color currentColor;
  final ValueChanged<Color> onColorPicked;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Custom color',
      child: GestureDetector(
        onTap: () async {
          final result = await showDialog<ColorPickerResult>(
            context: context,
            builder: (_) =>
                VioColorPickerDialog(initialColor: currentColor.toARGB32()),
          );
          if (result != null) {
            onColorPicked(Color(result.color));
          }
        },
        child: SizedBox(
          width: 32,
          height: 32,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              gradient: const SweepGradient(
                colors: [
                  Color(0xFFFF0000),
                  Color(0xFFFFFF00),
                  Color(0xFF00FF00),
                  Color(0xFF00FFFF),
                  Color(0xFF0000FF),
                  Color(0xFFFF00FF),
                  Color(0xFFFF0000),
                ],
              ),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 14),
          ),
        ),
      ),
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({
    required this.currentMode,
    required this.onChanged,
  });

  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SegmentedButton<ThemeMode>(
      style: SegmentedButton.styleFrom(
        backgroundColor: cs.surfaceContainerHigh,
        selectedBackgroundColor: cs.primary,
        selectedForegroundColor: cs.onPrimary,
        foregroundColor: cs.onSurfaceVariant,
        side: BorderSide(color: cs.outline.withValues(alpha: 0.25)),
      ),
      segments: const [
        ButtonSegment(
          value: ThemeMode.dark,
          icon: Icon(Icons.dark_mode_outlined, size: 16),
          label: Text('Dark'),
        ),
        ButtonSegment(
          value: ThemeMode.system,
          icon: Icon(Icons.brightness_auto_outlined, size: 16),
          label: Text('System'),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          icon: Icon(Icons.light_mode_outlined, size: 16),
          label: Text('Light'),
        ),
      ],
      selected: {currentMode},
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) onChanged(selection.first);
      },
    );
  }
}
