part of 'theme_bloc.dart';

/// Immutable snapshot of the active theme configuration.
///
/// [themeData] is computed on demand from [seedColor] and [themeMode].
/// Equatable props only include the inputs so that equality checks are
/// cheap (no deep ThemeData comparison).
final class ThemeState extends Equatable {
  const ThemeState({required this.seedColor, required this.themeMode});

  /// Default state — Vio primary blue seed, dark mode.
  factory ThemeState.initial() =>
      const ThemeState(seedColor: VioColors.primary, themeMode: ThemeMode.dark);

  /// The color used to generate the M3 [ColorScheme] via [VioTheme.fromSeed].
  final Color seedColor;

  /// Requested brightness mode.
  final ThemeMode themeMode;

  /// The fully constructed [ThemeData] for this state.
  ///
  /// Computed each time it is accessed; callers that need it frequently should
  /// cache it locally or wrap the consumer in a narrow [BlocBuilder].
  ThemeData get themeData => VioTheme.fromSeed(seedColor, mode: themeMode);

  ThemeState copyWith({Color? seedColor, ThemeMode? themeMode}) {
    return ThemeState(
      seedColor: seedColor ?? this.seedColor,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  @override
  List<Object?> get props => [seedColor, themeMode];
}
