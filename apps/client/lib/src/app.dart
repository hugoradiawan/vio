import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import 'features/canvas/bloc/canvas_bloc.dart';
import 'features/workspace/bloc/workspace_bloc.dart';
import 'features/workspace/presentation/workspace_page.dart';

/// Main application widget
class VioApp extends StatelessWidget {
  const VioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vio - Design Tool',
      debugShowCheckedModeBanner: false,
      theme: VioTheme.darkTheme,
      home: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => WorkspaceBloc()..add(const WorkspaceInitialized()),
          ),
          BlocProvider(
            create: (_) => CanvasBloc(),
          ),
        ],
        child: const WorkspacePage(),
      ),
    );
  }
}
