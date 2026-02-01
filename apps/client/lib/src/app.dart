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
            ),
            // Note: Canvas shapes are loaded via VersionControlBloc bridge,
            // not directly via CanvasLoadRequested, to ensure single source of truth
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
/// Also syncs VersionControlBloc branch switches back to CanvasBloc.
class _CanvasVersionControlBridge extends StatelessWidget {
  const _CanvasVersionControlBridge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Canvas → VersionControl: track shape changes for uncommitted detection
        BlocListener<CanvasBloc, CanvasState>(
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
        ),
        // VersionControl → Canvas: sync shapes when branch switches OR initial load completes
        BlocListener<VersionControlBloc, VersionControlState>(
          listenWhen: (previous, current) {
            // Listen when branch switch completes (status changes from switching to ready)
            final switchCompleted =
                previous.status == VersionControlStatus.switching &&
                    current.status == VersionControlStatus.ready;

            // Listen when initial load completes (status changes from loading to ready)
            final initialLoadCompleted =
                previous.status == VersionControlStatus.loading &&
                    current.status == VersionControlStatus.ready;

            return switchCompleted || initialLoadCompleted;
          },
          listener: (context, vcState) {
            final canvasBloc = context.read<CanvasBloc>();

            // Replace canvas shapes with the branch's shapes
            final newShapes = vcState.currentShapes;
            debugPrint(
              '[Bridge] Branch loaded/switched, updating canvas with ${newShapes.length} shapes',
            );

            // Log shape details for debugging
            for (final shape in newShapes.values) {
              debugPrint(
                '[Bridge] Shape: ${shape.id} type=${shape.type} name=${shape.name}',
              );
            }

            // Use ShapesReplaced event for efficient bulk update
            canvasBloc.add(ShapesReplaced(newShapes));
          },
        ),
      ],
      child: child,
    );
  }
}
