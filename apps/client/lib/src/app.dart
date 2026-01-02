import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import 'core/core.dart';
import 'features/canvas/bloc/canvas_bloc.dart';
import 'features/workspace/bloc/workspace_bloc.dart';
import 'features/workspace/presentation/workspace_page.dart';

// Demo project IDs (matching backend seed script)
const _demoProjectId = '00000000-0000-0000-0000-000000000001';
const _demoBranchId = '00000000-0000-0000-0000-000000000002';

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
            create: (_) => CanvasBloc(
              repository: ServiceLocator.instance.canvasRepository,
            )..add(const CanvasLoadRequested(
                projectId: _demoProjectId,
                branchId: _demoBranchId,
              ),),
          ),
        ],
        child: const WorkspacePage(),
      ),
    );
  }
}
