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
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc(
      authClient: ServiceLocator.instance.authService,
    )..add(const AuthCheckRequested());
    _router = createRouter(_authBloc);
  }

  @override
  void dispose() {
    _authBloc.close();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authBloc,
      child: MaterialApp.router(
        title: 'Vio - Design Tool',
        debugShowCheckedModeBanner: false,
        theme: VioTheme.darkTheme,
        routerConfig: _router,
      ),
    );
  }
}
