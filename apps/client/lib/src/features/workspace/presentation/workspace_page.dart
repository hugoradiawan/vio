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
class WorkspacePage extends StatefulWidget {
  const WorkspacePage({super.key});

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  final FocusNode _workspaceFocusNode = FocusNode();

  @override
  void dispose() {
    _workspaceFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkspaceBloc, WorkspaceState>(
      builder: (context, state) {
        return Shortcuts(
          shortcuts: _buildShortcutIntents(),
          child: Actions(
            actions: _buildActions(context),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                // Request focus for shortcuts when tapping outside text fields
                FocusScope.of(context).requestFocus(_workspaceFocusNode);
              },
              child: Focus(
                focusNode: _workspaceFocusNode,
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
            ),
          ),
        );
      },
    );
  }

  /// Build shortcut to intent mappings
  Map<ShortcutActivator, Intent> _buildShortcutIntents() {
    return {
      // Tool shortcuts - only single key, no modifiers
      // These will be skipped when focus is on text fields
      const SingleActivator(LogicalKeyboardKey.keyV): const _ToolIntent(CanvasTool.select),
      const SingleActivator(LogicalKeyboardKey.keyA): const _ToolIntent(CanvasTool.directSelect),
      const SingleActivator(LogicalKeyboardKey.keyR): const _ToolIntent(CanvasTool.rectangle),
      const SingleActivator(LogicalKeyboardKey.keyO): const _ToolIntent(CanvasTool.ellipse),
      const SingleActivator(LogicalKeyboardKey.keyP): const _ToolIntent(CanvasTool.path),
      const SingleActivator(LogicalKeyboardKey.keyT): const _ToolIntent(CanvasTool.text),
      const SingleActivator(LogicalKeyboardKey.keyF): const _ToolIntent(CanvasTool.frame),
      const SingleActivator(LogicalKeyboardKey.keyH): const _ToolIntent(CanvasTool.hand),
      const SingleActivator(LogicalKeyboardKey.keyZ): const _ToolIntent(CanvasTool.zoom),
      const SingleActivator(LogicalKeyboardKey.keyC): const _ToolIntent(CanvasTool.comment),

      // View shortcuts - with modifiers, safe to use
      const SingleActivator(LogicalKeyboardKey.backquote, control: true): const _GridToggleIntent(),
      const SingleActivator(LogicalKeyboardKey.quote, control: true): const _SnapToggleIntent(),
      const SingleActivator(LogicalKeyboardKey.keyR, control: true, shift: true): const _RulersToggleIntent(),

      // Panel shortcuts
      const SingleActivator(LogicalKeyboardKey.backslash, control: true): const _LeftPanelToggleIntent(),
      const SingleActivator(LogicalKeyboardKey.backslash, control: true, shift: true): const _RightPanelToggleIntent(),

      // Zoom shortcuts
      const SingleActivator(LogicalKeyboardKey.equal, control: true): const _ZoomInIntent(),
      const SingleActivator(LogicalKeyboardKey.minus, control: true): const _ZoomOutIntent(),
      const SingleActivator(LogicalKeyboardKey.digit0, control: true): const _ZoomResetIntent(),
      const SingleActivator(LogicalKeyboardKey.digit1, control: true): const _ZoomResetIntent(),
    };
  }

  /// Build action handlers
  Map<Type, Action<Intent>> _buildActions(BuildContext context) {
    final workspaceBloc = context.read<WorkspaceBloc>();
    final canvasBloc = context.read<CanvasBloc>();

    return {
      _ToolIntent: CallbackAction<_ToolIntent>(
        onInvoke: (intent) {
          // Don't trigger tool shortcuts when editing text
          final focus = FocusManager.instance.primaryFocus;
          if (focus?.context?.widget is EditableText) {
            return null;
          }
          workspaceBloc.add(ToolSelected(intent.tool));
          return null;
        },
      ),
      _GridToggleIntent: CallbackAction<_GridToggleIntent>(
        onInvoke: (_) {
          workspaceBloc.add(const GridToggled());
          return null;
        },
      ),
      _SnapToggleIntent: CallbackAction<_SnapToggleIntent>(
        onInvoke: (_) {
          workspaceBloc.add(const SnapToGridToggled());
          return null;
        },
      ),
      _RulersToggleIntent: CallbackAction<_RulersToggleIntent>(
        onInvoke: (_) {
          workspaceBloc.add(const RulersToggled());
          return null;
        },
      ),
      _LeftPanelToggleIntent: CallbackAction<_LeftPanelToggleIntent>(
        onInvoke: (_) {
          workspaceBloc.add(const LeftPanelToggled());
          return null;
        },
      ),
      _RightPanelToggleIntent: CallbackAction<_RightPanelToggleIntent>(
        onInvoke: (_) {
          workspaceBloc.add(const RightPanelToggled());
          return null;
        },
      ),
      _ZoomInIntent: CallbackAction<_ZoomInIntent>(
        onInvoke: (_) {
          canvasBloc.add(const ZoomIn());
          return null;
        },
      ),
      _ZoomOutIntent: CallbackAction<_ZoomOutIntent>(
        onInvoke: (_) {
          canvasBloc.add(const ZoomOut());
          return null;
        },
      ),
      _ZoomResetIntent: CallbackAction<_ZoomResetIntent>(
        onInvoke: (_) {
          canvasBloc.add(const ZoomSet(1.0));
          return null;
        },
      ),
    };
  }
}

// Intent classes for shortcuts
class _ToolIntent extends Intent {
  const _ToolIntent(this.tool);
  final CanvasTool tool;
}

class _GridToggleIntent extends Intent {
  const _GridToggleIntent();
}

class _SnapToggleIntent extends Intent {
  const _SnapToggleIntent();
}

class _RulersToggleIntent extends Intent {
  const _RulersToggleIntent();
}

class _LeftPanelToggleIntent extends Intent {
  const _LeftPanelToggleIntent();
}

class _RightPanelToggleIntent extends Intent {
  const _RightPanelToggleIntent();
}

class _ZoomInIntent extends Intent {
  const _ZoomInIntent();
}

class _ZoomOutIntent extends Intent {
  const _ZoomOutIntent();
}

class _ZoomResetIntent extends Intent {
  const _ZoomResetIntent();
}
