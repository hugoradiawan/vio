import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../theme/vio_colors.dart';
import '../theme/vio_theme.dart';

part 'theme_event.dart';
part 'theme_state.dart';

/// Manages the active [ThemeData] for the application.
///
/// Responds to [ThemeSeedChanged] and [ThemeModeChanged] to rebuild the theme
/// in real time. On startup, dispatch [ThemeLoaded] with values restored from
/// persistent storage (e.g. [PreferencesService]) so the user's last choice is
/// applied immediately.
///
/// Example bootstrap in [MaterialApp]:
/// ```dart
/// BlocProvider(
///   create: (_) => ThemeBloc()
///     ..add(ThemeLoaded(
///       seedColor: prefs.getThemeSeedColor(),
///       mode: prefs.getThemeMode(),
///     )),
///   child: BlocBuilder<ThemeBloc, ThemeState>(
///     builder: (context, state) => MaterialApp(
///       theme: state.themeData,
///       ...
///     ),
///   ),
/// )
/// ```
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc() : super(ThemeState.initial()) {
    on<ThemeLoaded>(_onLoaded);
    on<ThemeSeedChanged>(_onSeedChanged);
    on<ThemeModeChanged>(_onModeChanged);
  }

  void _onLoaded(ThemeLoaded event, Emitter<ThemeState> emit) {
    emit(state.copyWith(seedColor: event.seedColor, themeMode: event.mode));
  }

  void _onSeedChanged(ThemeSeedChanged event, Emitter<ThemeState> emit) {
    emit(state.copyWith(seedColor: event.seedColor));
  }

  void _onModeChanged(ThemeModeChanged event, Emitter<ThemeState> emit) {
    emit(state.copyWith(themeMode: event.mode));
  }
}
