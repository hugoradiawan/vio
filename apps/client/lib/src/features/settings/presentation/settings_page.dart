import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import 'widgets/theme_section.dart';

/// Top-level settings page.
///
/// Accessible at `/settings`. Displays user-configurable app preferences
/// organised into sections. Initially ships with the Theme section; expand
/// future sections here as needed.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurfaceVariant),
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(
          'Settings',
          style: VioTypography.titleLarge.copyWith(
            color: cs.onSurface,
          ),
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: SizedBox(
              height: 1,
              child: ColoredBox(color: cs.outline.withValues(alpha: 0.25))),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: VioSpacing.md),
        children: [
          // — Appearance ———————————————————————————————————————————————————
          const _SectionHeader(title: 'Appearance'),
          ThemeSection(
            onSeedChanged: (color) {
              context.read<ThemeBloc>().add(ThemeSeedChanged(color));
            },
            onModeChanged: (mode) {
              context.read<ThemeBloc>().add(ThemeModeChanged(mode));
            },
          ),
          const SizedBox(height: VioSpacing.xl),
        ],
      ),
    );
  }
}

/// Simple section header used inside the settings list.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VioSpacing.lg,
        VioSpacing.sm,
        VioSpacing.lg,
        VioSpacing.xs,
      ),
      child: Text(
        title.toUpperCase(),
        style: VioTypography.labelSmall.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
