import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import 'core/core.dart';
import 'features/canvas/bloc/canvas_bloc.dart';
import 'features/version_control/bloc/version_control_bloc.dart';
import 'features/workspace/bloc/workspace_bloc.dart';
import 'features/workspace/presentation/workspace_page.dart';

// Demo project IDs (matching backend seed script)
const _demoProjectId = '00000000-0000-0000-0000-000000000001';
const _demoBranchId = '00000000-0000-0000-0000-000000000002';
const _demoUserId = '00000000-0000-0000-0000-000000000099';

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
            )..add(
                const CanvasLoadRequested(
                  projectId: _demoProjectId,
                  branchId: _demoBranchId,
                ),
              ),
          ),
          BlocProvider(
            create: (_) => VersionControlBloc()
              ..add(
                const VersionControlInitialized(
                  projectId: _demoProjectId,
                  userId: _demoUserId,
                ),
              ),
          ),
        ],
        child: const _CanvasVersionControlBridge(
          child: WorkspacePage(),
        ),
      ),
    );
  }
}

/// Bridge widget that syncs CanvasBloc state changes to VersionControlBloc
/// for change detection (uncommitted changes tracking).
class _CanvasVersionControlBridge extends StatelessWidget {
  const _CanvasVersionControlBridge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<CanvasBloc, CanvasState>(
      listenWhen: (previous, current) {
        // Listen when shapes change
        return previous.shapes != current.shapes;
      },
      listener: (context, canvasState) {
        final vcBloc = context.read<VersionControlBloc>();
        
        // Always send current shapes when they change
        vcBloc.add(CanvasShapesChanged(shapes: canvasState.shapes));
        debugPrint(
          '[Bridge] Canvas shapes updated: ${canvasState.shapes.length} shapes',
        );
      },
      child: child,
    );
  }
}
