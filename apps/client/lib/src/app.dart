import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import 'core/core.dart';
import 'features/auth/bloc/auth_bloc.dart';

/// Main application widget
class VioApp extends StatefulWidget {
  const VioApp({super.key});

  @override
  State<VioApp> createState() => _VioAppState();
}

class _VioAppState extends State<VioApp> {
  late final AuthBloc _authBloc;
  late final ThemeBloc _themeBloc;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    _authBloc = AuthBloc(
      authClient: ServiceLocator.instance.authService,
    )..add(const AuthCheckRequested());

    final prefs = PreferencesService.instance;
    _themeBloc = ThemeBloc()
      ..add(
        ThemeLoaded(
          seedColor: prefs.getThemeSeedColor(),
          mode: prefs.getThemeMode(),
        ),
      );

    _router = createRouter(_authBloc);
  }

  @override
  void dispose() {
    _authBloc.close();
    _themeBloc.close();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authBloc),
        BlocProvider.value(value: _themeBloc),
      ],
      // Persist theme changes whenever state transitions occur.
      child: BlocListener<ThemeBloc, ThemeState>(
        listener: (context, state) {
          final prefs = PreferencesService.instance;
          prefs.setThemeSeedColor(state.seedColor);
          prefs.setThemeMode(state.themeMode);
        },
        child: BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, themeState) {
            return MaterialApp.router(
              title: 'Vio - Design Tool',
              debugShowCheckedModeBanner: false,
              theme: themeState.themeData,
              themeMode: themeState.themeMode,
              routerConfig: _router,
            );
          },
        ),
      ),
    );
  }
}
