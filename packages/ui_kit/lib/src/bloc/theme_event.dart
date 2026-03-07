part of 'theme_bloc.dart';

/// Base class for all theme-related events.
sealed class ThemeEvent extends Equatable {
  const ThemeEvent();
}

/// Restore previously persisted theme settings on app startup.
final class ThemeLoaded extends ThemeEvent {
  const ThemeLoaded({required this.seedColor, required this.mode});

  final Color seedColor;
  final ThemeMode mode;

  @override
  List<Object?> get props => [seedColor, mode];
}

/// User selected a new seed color in Settings.
final class ThemeSeedChanged extends ThemeEvent {
  const ThemeSeedChanged(this.seedColor);

  final Color seedColor;

  @override
  List<Object?> get props => [seedColor];
}

/// User toggled theme brightness (dark / light / system).
final class ThemeModeChanged extends ThemeEvent {
  const ThemeModeChanged(this.mode);

  final ThemeMode mode;

  @override
  List<Object?> get props => [mode];
}
