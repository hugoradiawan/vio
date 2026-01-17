import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_client/src/features/canvas/bloc/canvas_bloc.dart';
import 'package:vio_client/src/features/workspace/bloc/workspace_bloc.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../canvas/presentation/widgets/layer_tree.dart';

/// Left panel containing layers tree and assets browser
class LeftPanel extends StatefulWidget {
  const LeftPanel({super.key});

  @override
  State<LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends State<LeftPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: VioColors.surface1,
        border: Border(
          right: BorderSide(
            color: VioColors.border,
          ),
        ),
      ),
      child: Column(
        children: [
          // Tab bar
          Container(
            height: 40,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: VioColors.border,
                ),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: VioSpacing.md),
                // Logo
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: VioColors.primary,
                    borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
                  ),
                  child: const Center(
                    child: Text(
                      'V',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    labelColor: VioColors.textPrimary,
                    unselectedLabelColor: VioColors.textTertiary,
                    indicatorColor: VioColors.primary,
                    labelStyle: VioTypography.body2,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Layers'),
                      Tab(text: 'Assets'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _LayersTab(),
                _AssetsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LayersTab extends StatelessWidget {
  const _LayersTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar
        BlocBuilder<WorkspaceBloc, WorkspaceState>(
          buildWhen: (prev, curr) =>
              prev.isLayersSearchOpen != curr.isLayersSearchOpen ||
              prev.layersSearchQuery != curr.layersSearchQuery,
          builder: (context, workspaceState) {
            return Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: VioSpacing.xs),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: VioColors.border,
                  ),
                ),
              ),
              child: Row(
                children: [
                  if (!workspaceState.isLayersSearchOpen) ...[
                    VioIconButton(
                      icon: Icons.folder_outlined,
                      size: 28,
                      tooltip: 'New Group',
                      onPressed: () {
                        context.read<CanvasBloc>().add(
                              const CreateGroupFromSelection(),
                            );
                      },
                    ),
                    const Spacer(),
                    VioIconButton(
                      icon: Icons.search,
                      size: 28,
                      tooltip: 'Search',
                      onPressed: () {
                        context
                            .read<WorkspaceBloc>()
                            .add(const LayersSearchToggled());
                      },
                    ),
                  ] else ...[
                    const SizedBox(width: VioSpacing.xs),
                    Expanded(
                      child: TextField(
                        autofocus: true,
                        style: VioTypography.body2.copyWith(
                          color: VioColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'Search layers…',
                          border: InputBorder.none,
                        ),
                        onChanged: (value) {
                          context
                              .read<WorkspaceBloc>()
                              .add(LayersSearchQueryChanged(value));
                        },
                      ),
                    ),
                    VioIconButton(
                      icon: Icons.close,
                      size: 28,
                      tooltip: 'Close search',
                      onPressed: () {
                        context
                            .read<WorkspaceBloc>()
                            .add(const LayersSearchCleared());
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        ),

        // Layers list
        Expanded(
          child: BlocBuilder<WorkspaceBloc, WorkspaceState>(
            buildWhen: (prev, curr) =>
                prev.isLayersSearchOpen != curr.isLayersSearchOpen ||
                prev.layersSearchQuery != curr.layersSearchQuery,
            builder: (context, workspaceState) {
              return LayerTree(
                searchQuery: workspaceState.layersSearchQuery,
                searchOpen: workspaceState.isLayersSearchOpen,
              );
            },
          ),
        ),

        // Bottom controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildViewToggles(context),
            _buildZoomControls(context),
          ],
        ),
      ],
    );
  }
}

Widget _buildZoomControls(BuildContext context) {
  return BlocBuilder<CanvasBloc, CanvasState>(
    buildWhen: (prev, curr) => prev.zoom != curr.zoom,
    builder: (context, state) {
      final zoomPercentage = '${(state.zoom * 100).round()}%';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zoom out
          VioIconButton(
            icon: Icons.remove,
            size: 24,
            tooltip: 'Zoom Out (Ctrl+-)',
            onPressed: () {
              context.read<CanvasBloc>().add(const ZoomOut());
            },
          ),

          // Zoom percentage dropdown
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

          // Zoom in
          VioIconButton(
            icon: Icons.add,
            size: 24,
            tooltip: 'Zoom In (Ctrl++)',
            onPressed: () {
              context.read<CanvasBloc>().add(const ZoomIn());
            },
          ),

          const SizedBox(width: VioSpacing.sm),

          // Fit to screen
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
            tooltip: 'Show Grid (Ctrl+`)',
            isActive: state.showGrid,
            onPressed: () {
              context.read<WorkspaceBloc>().add(const GridToggled());
            },
          ),
          _ToggleButton(
            icon: Icons.grid_on,
            tooltip: 'Snap to Grid (Ctrl+\')',
            isActive: state.snapToGrid,
            onPressed: () {
              context.read<WorkspaceBloc>().add(const SnapToGridToggled());
            },
          ),
          _ToggleButton(
            icon: Icons.straighten,
            tooltip: 'Show Rulers (Ctrl+Shift+R)',
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

class _AssetsTab extends StatelessWidget {
  const _AssetsTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Asset categories
        VioPanel(
          title: 'Components',
          child: _buildEmptyState(
            icon: Icons.widgets_outlined,
            message: 'No components',
          ),
        ),
        VioPanel(
          title: 'Graphics',
          child: _buildEmptyState(
            icon: Icons.image_outlined,
            message: 'No graphics',
          ),
        ),
        VioPanel(
          title: 'Colors',
          child: _buildEmptyState(
            icon: Icons.palette_outlined,
            message: 'No colors',
          ),
        ),
        VioPanel(
          title: 'Typographies',
          child: _buildEmptyState(
            icon: Icons.text_fields,
            message: 'No typographies',
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.all(VioSpacing.md),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: VioColors.textTertiary,
            ),
            const SizedBox(height: VioSpacing.xs),
            Text(
              message,
              style: VioTypography.caption.copyWith(
                color: VioColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
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
