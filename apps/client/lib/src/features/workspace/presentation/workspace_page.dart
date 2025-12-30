import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../canvas/bloc/canvas_bloc.dart';
import '../../canvas/presentation/canvas_view.dart';
import '../bloc/workspace_bloc.dart';
import 'widgets/bottom_bar.dart';
import 'widgets/left_panel.dart';
import 'widgets/right_panel.dart';
import 'widgets/top_toolbar.dart';

/// Main workspace page containing:
/// - Top toolbar with tools and actions
/// - Left panel for layers and assets
/// - Center canvas area
/// - Right panel for properties
/// - Bottom bar with zoom controls
class WorkspacePage extends StatelessWidget {
  const WorkspacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkspaceBloc, WorkspaceState>(
      builder: (context, state) {
        return CallbackShortcuts(
          bindings: _buildShortcuts(context),
          child: Focus(
            autofocus: true,
            child: Scaffold(
              backgroundColor: VioColors.background,
              body: Column(
                children: [
                  // Top toolbar
                  const TopToolbar(),
                  // Main content area
                  Expanded(
                    child: Row(
                      children: [
                        // Left panel (layers, assets)
                        if (state.isLeftPanelVisible) const LeftPanel(),
                        // Canvas area
                        Expanded(
                          child: Container(
                            color: VioColors.canvasBackground,
                            child: const CanvasView(),
                          ),
                        ),
                        // Right panel (properties)
                        if (state.isRightPanelVisible) const RightPanel(),
                      ],
                    ),
                  ),
                  // Bottom bar (zoom, view controls)
                  const BottomBar(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build keyboard shortcuts mapping
  Map<ShortcutActivator, VoidCallback> _buildShortcuts(BuildContext context) {
    final workspaceBloc = context.read<WorkspaceBloc>();
    final canvasBloc = context.read<CanvasBloc>();

    return {
      // Tool shortcuts
      const SingleActivator(LogicalKeyboardKey.keyV): () =>
          workspaceBloc.add(const ToolSelected(CanvasTool.select)),
      const SingleActivator(LogicalKeyboardKey.keyA): () =>
          workspaceBloc.add(const ToolSelected(CanvasTool.directSelect)),
      const SingleActivator(LogicalKeyboardKey.keyR): () =>
          workspaceBloc.add(const ToolSelected(CanvasTool.rectangle)),
      const SingleActivator(LogicalKeyboardKey.keyO): () =>
          workspaceBloc.add(const ToolSelected(CanvasTool.ellipse)),
      const SingleActivator(LogicalKeyboardKey.keyP): () =>
          workspaceBloc.add(const ToolSelected(CanvasTool.path)),
      const SingleActivator(LogicalKeyboardKey.keyT): () =>
          workspaceBloc.add(const ToolSelected(CanvasTool.text)),
      const SingleActivator(LogicalKeyboardKey.keyF): () =>
          workspaceBloc.add(const ToolSelected(CanvasTool.frame)),
      const SingleActivator(LogicalKeyboardKey.keyH): () =>
          workspaceBloc.add(const ToolSelected(CanvasTool.hand)),
      const SingleActivator(LogicalKeyboardKey.keyZ): () =>
          workspaceBloc.add(const ToolSelected(CanvasTool.zoom)),
      const SingleActivator(LogicalKeyboardKey.keyC): () =>
          workspaceBloc.add(const ToolSelected(CanvasTool.comment)),

      // View shortcuts
      const SingleActivator(LogicalKeyboardKey.backquote, control: true): () =>
          workspaceBloc.add(const GridToggled()),
      const SingleActivator(LogicalKeyboardKey.quote, control: true): () =>
          workspaceBloc.add(const SnapToGridToggled()),
      const SingleActivator(
        LogicalKeyboardKey.keyR,
        control: true,
        shift: true,
      ): () => workspaceBloc.add(const RulersToggled()),

      // Panel shortcuts
      const SingleActivator(LogicalKeyboardKey.backslash, control: true): () =>
          workspaceBloc.add(const LeftPanelToggled()),
      const SingleActivator(
        LogicalKeyboardKey.backslash,
        control: true,
        shift: true,
      ): () => workspaceBloc.add(const RightPanelToggled()),

      // Zoom shortcuts - use CanvasBloc for actual viewport zoom
      const SingleActivator(LogicalKeyboardKey.equal, control: true): () =>
          canvasBloc.add(const ZoomIn()),
      const SingleActivator(LogicalKeyboardKey.minus, control: true): () =>
          canvasBloc.add(const ZoomOut()),
      const SingleActivator(LogicalKeyboardKey.digit0, control: true): () =>
          canvasBloc.add(const ZoomSet(1.0)),
      const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
          canvasBloc.add(const ZoomSet(1.0)),
    };
  }
}
