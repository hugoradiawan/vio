import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_client/src/features/canvas/bloc/canvas_bloc.dart';
import 'package:vio_client/src/features/version_control/presentation/widgets/version_control_tab.dart';
import 'package:vio_client/src/features/workspace/bloc/workspace_bloc.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../assets/presentation/widgets/assets_tab.dart';
import '../../../canvas/presentation/widgets/layer_tree.dart';
import 'search_tab.dart';

/// Left panel containing layers tree and assets browser
class LeftPanel extends StatefulWidget {
  const LeftPanel({
    required this.width,
    super.key,
  });

  /// Width of the panel in logical pixels.
  final double width;

  @override
  State<LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends State<LeftPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  void _openLayersFromSearchResult({
    required String shapeId,
  }) {
    _tabController.animateTo(0);
    context.read<CanvasBloc>().add(ShapeSelected(shapeId));
    context.read<CanvasBloc>().add(const SelectionCentered());
  }

  void _setLayerHoverFromSearchResult(String? shapeId) {
    context.read<CanvasBloc>().add(LayerHovered(shapeId));
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
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
                      Tab(
                        icon: Tooltip(
                          message: 'Layers',
                          child: Icon(Icons.layers_outlined, size: 18),
                        ),
                      ),
                      Tab(
                        icon: Tooltip(
                          message: 'Assets',
                          child: Icon(Icons.perm_media_outlined, size: 18),
                        ),
                      ),
                      Tab(
                        icon: Tooltip(
                          message: 'Version Control',
                          child: Icon(Icons.merge_outlined, size: 18),
                        ),
                      ),
                      Tab(
                        icon: Tooltip(
                          message: 'Search',
                          child: Icon(Icons.search_outlined, size: 18),
                        ),
                      ),
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
              children: [
                const _LayersTab(),
                const AssetsTab(),
                const VersionControlTab(),
                SearchTab(
                  onLayerResultTap: _openLayersFromSearchResult,
                  onLayerResultHoverChanged: _setLayerHoverFromSearchResult,
                ),
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
      ],
    );
  }
}
