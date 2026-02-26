import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../core/platform_shortcuts.dart';
import '../../canvas/bloc/canvas_bloc.dart';
import '../../canvas/presentation/canvas_view.dart';
import '../bloc/workspace_bloc.dart';
import 'widgets/left_panel.dart';
import 'widgets/resizable_panel_handle.dart';
import 'widgets/right_panel.dart';

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
  bool _isEditingText = false;

  @override
  void initState() {
    super.initState();
    _syncIsEditingText();
    FocusManager.instance.addListener(_handleFocusChange);
    // Ensure workspace has focus for keyboard shortcuts/logging after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_workspaceFocusNode.hasFocus) {
        _workspaceFocusNode.requestFocus();
      }
    });
  }

  void _handleFocusChange() {
    final prev = _isEditingText;
    _syncIsEditingText();
    if (mounted && prev != _isEditingText) {
      setState(() {});
    }
  }

  void _syncIsEditingText() {
    final focus = FocusManager.instance.primaryFocus;
    _isEditingText = focus?.context?.widget is EditableText ||
        focus?.context?.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChange);
    _workspaceFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkspaceBloc, WorkspaceState>(
      builder: (context, state) {
        return Shortcuts(
          shortcuts: _buildShortcutIntents(
            includeToolShortcuts: !_isEditingText,
          ),
          child: Actions(
            actions: _buildActions(context),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                // Request focus for shortcuts when tapping outside text fields.
                // IMPORTANT: Don't steal focus during inline text editing,
                // otherwise the TextField immediately blurs and auto-commits.
                final isEditingText = _isEditingText ||
                    context.read<CanvasBloc>().state.editingTextShapeId != null;
                if (isEditingText) {
                  return;
                }

                FocusScope.of(context).requestFocus(_workspaceFocusNode);
              },
              child: Focus(
                focusNode: _workspaceFocusNode,
                onKeyEvent: (node, event) {
                  // Debug log pressed keys
                  final pressed = HardwareKeyboard.instance.logicalKeysPressed
                      .map((k) => k.debugName)
                      .join(', ');
                  debugPrint(
                    'Key event: logical=${event.logicalKey.debugName}, physical=${event.physicalKey.debugName}, type=${event.runtimeType}, pressed=[$pressed]',
                  );
                  return KeyEventResult.ignored;
                },
                child: Scaffold(
                  backgroundColor: VioColors.background,
                  body: Column(
                    children: [
                      // Main content area
                      Expanded(
                        child: Stack(
                          children: [
                            Row(
                              children: [
                                // Left panel
                                if (state.isLeftPanelVisible)
                                  LeftPanel(width: state.leftPanelWidth),
                                // Canvas area
                                Expanded(
                                  child: Container(
                                    color: VioColors.canvasBackground,
                                    child: Stack(
                                      children: [
                                        const CanvasView(),
                                        Positioned(
                                          right: VioSpacing.md,
                                          bottom: VioSpacing.sm,
                                          child: _buildCanvasBottomRightControls(
                                            context,
                                          ),
                                        ),
                                        Positioned(
                                          bottom: VioSpacing.sm,
                                          left: 0,
                                          right: 0,
                                          child: Center(
                                            child: ConstrainedBox(
                                              constraints:
                                                  const BoxConstraints(
                                                maxWidth: 640,
                                              ),
                                              child:
                                                  _buildToolsSection(context),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Right panel
                                if (state.isRightPanelVisible)
                                  RightPanel(width: state.rightPanelWidth),
                              ],
                            ),
                            // Left panel resize handle (overlay)
                            if (state.isLeftPanelVisible)
                              Positioned(
                                left: state.leftPanelWidth - 6,
                                top: 0,
                                bottom: 0,
                                width: 12,
                                child: ResizablePanelHandle(
                                  onDragUpdate: (delta) {
                                    final bloc =
                                        context.read<WorkspaceBloc>();
                                    final currentWidth =
                                        bloc.state.leftPanelWidth;
                                    bloc.add(
                                      LeftPanelWidthChanged(
                                        currentWidth + delta,
                                      ),
                                    );
                                  },
                                  onDoubleTap: () {
                                    context.read<WorkspaceBloc>().add(
                                          const LeftPanelWidthReset(),
                                        );
                                  },
                                ),
                              ),
                            // Right panel resize handle (overlay)
                            if (state.isRightPanelVisible)
                              Positioned(
                                right: state.rightPanelWidth - 6,
                                top: 0,
                                bottom: 0,
                                width: 12,
                                child: ResizablePanelHandle(
                                  isLeftSide: false,
                                  onDragUpdate: (delta) {
                                    final bloc =
                                        context.read<WorkspaceBloc>();
                                    final currentWidth =
                                        bloc.state.rightPanelWidth;
                                    bloc.add(
                                      RightPanelWidthChanged(
                                        currentWidth - delta,
                                      ),
                                    );
                                  },
                                  onDoubleTap: () {
                                    context.read<WorkspaceBloc>().add(
                                          const RightPanelWidthReset(),
                                        );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
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

  Widget _buildToolsSection(BuildContext context) {
    return BlocBuilder<WorkspaceBloc, WorkspaceState>(
      buildWhen: (prev, curr) => prev.activeTool != curr.activeTool,
      builder: (context, state) {
        return VioCanvasToolbar(
          selectedToolId: _mapToolToToolItem(state.activeTool),
          onToolSelected: (tool) {
            final canvasTool = _mapToolItemToTool(tool);
            if (canvasTool != null) {
              context.read<WorkspaceBloc>().add(ToolSelected(canvasTool));
            }
          },
          tools: const [
            ToolbarToolItem(
              id: 'select',
              icon: Icons.near_me_outlined,
              tooltip: 'Select (V)',
            ),
            ToolbarToolItem(
              id: 'direct',
              icon: Icons.touch_app_outlined,
              tooltip: 'Direct Select (A)',
            ),
            ToolbarToolItem(
              id: 'rectangle',
              icon: Icons.rectangle_outlined,
              tooltip: 'Rectangle (R)',
            ),
            ToolbarToolItem(
              id: 'ellipse',
              icon: Icons.circle_outlined,
              tooltip: 'Ellipse (O)',
            ),
            ToolbarToolItem(
              id: 'path',
              icon: Icons.timeline,
              tooltip: 'Path (P)',
            ),
            ToolbarToolItem(
              id: 'text',
              icon: Icons.text_fields,
              tooltip: 'Text (T)',
            ),
            ToolbarToolItem(
              id: 'frame',
              icon: Icons.crop_free,
              tooltip: 'Frame (F)',
            ),
            ToolbarToolItem(
              id: 'hand',
              icon: Icons.pan_tool_outlined,
              tooltip: 'Hand (H)',
            ),
          ],
        );
      },
    );
  }

  Widget _buildCanvasBottomRightControls(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildViewToggles(context),
        const SizedBox(width: VioSpacing.md),
        _buildZoomControls(context),
      ],
    );
  }

  Widget _buildZoomControls(BuildContext context) {
    return BlocBuilder<CanvasBloc, CanvasState>(
      buildWhen: (prev, curr) => prev.zoom != curr.zoom,
      builder: (context, state) {
        final zoomPercentage = '${(state.zoom * 100).round()}%';
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            VioIconButton(
              icon: Icons.remove,
              size: 24,
              tooltip: 'Zoom Out (${platformModifierLabel()}+-)',
              onPressed: () {
                context.read<CanvasBloc>().add(const ZoomOut());
              },
            ),
            SizedBox(
              width: 64,
              child: PopupMenuButton<double>(
                initialValue: state.zoom,
                tooltip: 'Zoom Level',
                offset: const Offset(0, -200),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: VioSpacing.xs,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        zoomPercentage,
                        style: VioTypography.caption.copyWith(
                          color: VioColors.textSecondary,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        size: 16,
                        color: VioColors.textTertiary,
                      ),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 0.25, child: Text('25%')),
                  const PopupMenuItem(value: 0.5, child: Text('50%')),
                  const PopupMenuItem(value: 0.75, child: Text('75%')),
                  const PopupMenuItem(value: 1.0, child: Text('100%')),
                  const PopupMenuItem(value: 1.5, child: Text('150%')),
                  const PopupMenuItem(value: 2.0, child: Text('200%')),
                  const PopupMenuItem(value: 4.0, child: Text('400%')),
                  const PopupMenuItem(value: 8.0, child: Text('800%')),
                ],
                onSelected: (zoom) {
                  context.read<CanvasBloc>().add(ZoomSet(zoom));
                },
              ),
            ),
            VioIconButton(
              icon: Icons.add,
              size: 24,
              tooltip: 'Zoom In (${platformModifierLabel()}++)',
              onPressed: () {
                context.read<CanvasBloc>().add(const ZoomIn());
              },
            ),
            const SizedBox(width: VioSpacing.sm),
            VioIconButton(
              icon: Icons.fit_screen,
              size: 24,
              tooltip: 'Fit to Screen',
              onPressed: () {
                context.read<CanvasBloc>().add(const ZoomSet(1.0));
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildViewToggles(BuildContext context) {
    return BlocBuilder<WorkspaceBloc, WorkspaceState>(
      buildWhen: (prev, curr) =>
          prev.showGrid != curr.showGrid ||
          prev.snapToGrid != curr.snapToGrid ||
          prev.showRulers != curr.showRulers,
      builder: (context, state) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToggleButton(
              icon: Icons.grid_4x4,
              tooltip: 'Show Grid (${platformModifierLabel()}+`)',
              isActive: state.showGrid,
              onPressed: () {
                context.read<WorkspaceBloc>().add(const GridToggled());
              },
            ),
            _ToggleButton(
              icon: Icons.grid_on,
              tooltip: 'Snap to Grid (${platformModifierLabel()}+\')',
              isActive: state.snapToGrid,
              onPressed: () {
                context.read<WorkspaceBloc>().add(const SnapToGridToggled());
              },
            ),
            _ToggleButton(
              icon: Icons.straighten,
              tooltip: 'Show Rulers (${platformModifierLabel()}+Shift+R)',
              isActive: state.showRulers,
              onPressed: () {
                context.read<WorkspaceBloc>().add(const RulersToggled());
              },
            ),
          ],
        );
      },
    );
  }

  String? _mapToolToToolItem(CanvasTool tool) {
    return switch (tool) {
      CanvasTool.select => 'select',
      CanvasTool.directSelect => 'direct',
      CanvasTool.rectangle => 'rectangle',
      CanvasTool.ellipse => 'ellipse',
      CanvasTool.path => 'path',
      CanvasTool.text => 'text',
      CanvasTool.frame => 'frame',
      CanvasTool.hand => 'hand',
      CanvasTool.zoom => null,
      CanvasTool.comment => null,
    };
  }

  CanvasTool? _mapToolItemToTool(String id) {
    return switch (id) {
      'select' => CanvasTool.select,
      'direct' => CanvasTool.directSelect,
      'rectangle' => CanvasTool.rectangle,
      'ellipse' => CanvasTool.ellipse,
      'path' => CanvasTool.path,
      'text' => CanvasTool.text,
      'frame' => CanvasTool.frame,
      'hand' => CanvasTool.hand,
      _ => null,
    };
  }

  /// Build shortcut to intent mappings
  Map<ShortcutActivator, Intent> _buildShortcutIntents({
    required bool includeToolShortcuts,
  }) {
    return {
      if (includeToolShortcuts) ...{
        // Tool shortcuts - only single key, no modifiers
        const SingleActivator(LogicalKeyboardKey.keyV):
            const _ToolIntent(CanvasTool.select),
        const SingleActivator(LogicalKeyboardKey.keyA):
            const _ToolIntent(CanvasTool.directSelect),
        const SingleActivator(LogicalKeyboardKey.keyR):
            const _ToolIntent(CanvasTool.rectangle),
        const SingleActivator(LogicalKeyboardKey.keyO):
            const _ToolIntent(CanvasTool.ellipse),
        const SingleActivator(LogicalKeyboardKey.keyP):
            const _ToolIntent(CanvasTool.path),
        const SingleActivator(LogicalKeyboardKey.keyT):
            const _ToolIntent(CanvasTool.text),
        const SingleActivator(LogicalKeyboardKey.keyF):
            const _ToolIntent(CanvasTool.frame),
        const SingleActivator(LogicalKeyboardKey.keyH):
            const _ToolIntent(CanvasTool.hand),
        const SingleActivator(LogicalKeyboardKey.keyC):
            const _ToolIntent(CanvasTool.comment),
      },

      // View shortcuts - with modifiers, safe to use
      platformSingleActivator(LogicalKeyboardKey.backquote):
          const _GridToggleIntent(),
      platformSingleActivator(LogicalKeyboardKey.quote):
          const _SnapToggleIntent(),
      platformSingleActivator(LogicalKeyboardKey.keyR, shift: true):
          const _RulersToggleIntent(),

      // Panel shortcuts
      platformSingleActivator(LogicalKeyboardKey.backslash):
          const _ZenModeToggleIntent(),
      platformSingleActivator(LogicalKeyboardKey.backslash, shift: true):
          const _RightPanelToggleIntent(),
      // Some platforms report Shift+\\ as LogicalKeyboardKey.bar instead of backslash
      platformSingleActivator(LogicalKeyboardKey.bar, shift: true):
          const _RightPanelToggleIntent(),
      // Some keyboards send intlBackslash scancode
      platformSingleActivator(LogicalKeyboardKey.intlBackslash):
          const _ZenModeToggleIntent(),
      platformSingleActivator(LogicalKeyboardKey.intlBackslash, shift: true):
          const _RightPanelToggleIntent(),

      // Keep an explicit left-panel toggle as a fallback.
      platformSingleActivator(LogicalKeyboardKey.backslash, alt: true):
          const _LeftPanelToggleIntent(),
      platformSingleActivator(LogicalKeyboardKey.intlBackslash, alt: true):
          const _LeftPanelToggleIntent(),

      // Zoom shortcuts
      platformSingleActivator(LogicalKeyboardKey.equal):
          const _ZoomInIntent(),
      platformSingleActivator(LogicalKeyboardKey.minus):
          const _ZoomOutIntent(),
      platformSingleActivator(LogicalKeyboardKey.digit0):
          const _ZoomResetIntent(),
      platformSingleActivator(LogicalKeyboardKey.digit1):
          const _ZoomResetIntent(),
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
          final isEditingText = focus?.context?.widget is EditableText ||
              focus?.context?.findAncestorWidgetOfExactType<EditableText>() !=
                  null;
          if (isEditingText) {
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
      _ZenModeToggleIntent: CallbackAction<_ZenModeToggleIntent>(
        onInvoke: (_) {
          workspaceBloc.add(const ZenModeToggled());
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

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: VioSpacing.xs,
            vertical: VioSpacing.xs / 2,
          ),
          child: Icon(
            icon,
            size: 16,
            color: isActive ? VioColors.primary : VioColors.textTertiary,
          ),
        ),
      ),
    );
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

class _ZenModeToggleIntent extends Intent {
  const _ZenModeToggleIntent();
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
