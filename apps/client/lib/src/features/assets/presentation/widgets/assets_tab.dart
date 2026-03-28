import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_core/vio_core.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../canvas/bloc/canvas_bloc.dart';
import '../../bloc/asset_bloc.dart';

/// Assets tab in the left panel.
///
/// Shows Graphics and Colors sections with search, upload,
/// and drag-and-drop support. Components and Typographies
/// are shown as placeholders for now.
class AssetsTab extends StatelessWidget {
  const AssetsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AssetBloc, AssetState>(
      builder: (context, state) {
        return Column(
          children: [
            // Search bar + controls
            _AssetsToolbar(state: state),

            // Scrollable asset content
            Expanded(
              child: state.status == AssetStatus.loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        // Components (placeholder)
                        VioPanel(
                          title: 'Components',
                          collapsible: true,
                          initiallyExpanded: false,
                          child: _buildEmptyState(
                            context,
                            icon: Icons.widgets_outlined,
                            message: 'Coming soon',
                          ),
                        ),

                        // Graphics
                        _GraphicsSection(
                          assets: state.filteredAssets,
                          viewMode: state.viewMode,
                          projectId: state.projectId,
                        ),

                        // Colors
                        _ColorsSection(
                          colors: state.filteredColors.cast<ProjectColor>(),
                          projectId: state.projectId,
                        ),

                        // Typographies (placeholder)
                        VioPanel(
                          title: 'Typographies',
                          collapsible: true,
                          initiallyExpanded: false,
                          child: _buildEmptyState(
                            context,
                            icon: Icons.text_fields,
                            message: 'Coming soon',
                          ),
                        ),
                      ],
                    ),
            ),

            // Error message
            if (state.errorMessage != null)
              Container(
                padding: const EdgeInsets.all(VioSpacing.xs),
                color: Theme.of(context).colorScheme.errorContainer,
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 14,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: VioSpacing.xs),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: VioTypography.caption.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  static Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String message,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(VioSpacing.md),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: cs.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: VioSpacing.xs),
            Text(
              message,
              style: VioTypography.caption.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.25),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Toolbar
// =============================================================================

class _AssetsToolbar extends StatelessWidget {
  const _AssetsToolbar({required this.state});

  final AssetState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: VioSpacing.xs),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: Row(
        children: [
          // Search
          Expanded(
            child: TextField(
              style: VioTypography.body2
                  .copyWith(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search assets…',
                hintStyle: VioTypography.body2.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                border: InputBorder.none,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.25),
                  ),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 24, minHeight: 16),
              ),
              onChanged: (value) {
                context.read<AssetBloc>().add(AssetSearchChanged(query: value));
              },
            ),
          ),

          // View mode toggle
          VioIconButton(
            icon: state.viewMode == AssetViewMode.grid
                ? Icons.grid_view
                : Icons.view_list,
            size: 24,
            tooltip: 'Toggle view mode',
            onPressed: () {
              context.read<AssetBloc>().add(AssetViewModeToggled());
            },
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Graphics Section
// =============================================================================

class _GraphicsSection extends StatefulWidget {
  const _GraphicsSection({
    required this.assets,
    required this.viewMode,
    this.projectId,
  });

  final List<ProjectAsset> assets;
  final AssetViewMode viewMode;
  final String? projectId;

  @override
  State<_GraphicsSection> createState() => _GraphicsSectionState();
}

class _GraphicsSectionState extends State<_GraphicsSection> {
  bool _isDroppingFile = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDroppingFile = true),
      onDragExited: (_) => setState(() => _isDroppingFile = false),
      onDragDone: (details) {
        setState(() => _isDroppingFile = false);
        _handleOsDrop(context, details);
      },
      child: VioPanel(
        title: 'Graphics',
        collapsible: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.assets.length}',
              style: VioTypography.caption.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: VioSpacing.xs),
            VioIconButton(
              icon: Icons.add,
              size: 20,
              tooltip: 'Upload graphic',
              onPressed: () => _uploadAsset(context),
            ),
          ],
        ),
        child: Stack(
          children: [
            widget.assets.isEmpty && !_isDroppingFile
                ? AssetsTab._buildEmptyState(
                    context,
                    icon: Icons.image_outlined,
                    message: 'No graphics\nDrag & drop or click + to add',
                  )
                : widget.viewMode == AssetViewMode.grid
                    ? _buildGrid(context)
                    : _buildList(context),
            // Drop overlay indicator
            if (_isDroppingFile)
              Container(
                margin: const EdgeInsets.all(VioSpacing.xs),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: VioSpacing.xs),
                      Text(
                        'Drop to upload',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    return BlocBuilder<AssetBloc, AssetState>(
      buildWhen: (prev, curr) => prev.assetDataCache != curr.assetDataCache,
      builder: (context, assetState) {
        return Padding(
          padding: const EdgeInsets.all(VioSpacing.xs),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const crossAxisCount = 2;
              const spacing = VioSpacing.xs;
              final itemWidth =
                  (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                      crossAxisCount;
              final itemHeight = itemWidth + 20; // Extra space for label

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: widget.assets.map((asset) {
                  return SizedBox(
                    width: itemWidth,
                    height: itemHeight,
                    child: _AssetGridItem(
                      asset: asset,
                      cachedData: assetState.assetDataCache[asset.id],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildList(BuildContext context) {
    return Column(
      children:
          widget.assets.map((asset) => _AssetListItem(asset: asset)).toList(),
    );
  }

  /// Handle files dropped from the OS onto the graphics panel.
  Future<void> _handleOsDrop(
    BuildContext context,
    DropDoneDetails details,
  ) async {
    final projectId = widget.projectId;
    if (projectId == null || projectId.isEmpty) return;

    const allowedExtensions = {
      'png',
      'jpg',
      'jpeg',
      'gif',
      'webp',
      'svg',
    };
    const mimeMap = {
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'svg': 'image/svg+xml',
    };

    final bloc = context.read<AssetBloc>();
    for (final xFile in details.files) {
      final name = xFile.name;
      final ext = name.split('.').last.toLowerCase();
      if (!allowedExtensions.contains(ext)) continue;

      final bytes = await xFile.readAsBytes();
      if (bytes.isEmpty) continue;

      final mimeType = mimeMap[ext] ?? 'application/octet-stream';

      bloc.add(
        AssetUploaded(
          projectId: projectId,
          name: name,
          mimeType: mimeType,
          data: bytes,
        ),
      );
    }
  }

  Future<void> _uploadAsset(BuildContext context) async {
    final projectId = widget.projectId;
    if (projectId == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg'],
      allowMultiple: true,
      withData: true,
    );

    if (result == null || !context.mounted) return;

    final bloc = context.read<AssetBloc>();
    for (final file in result.files) {
      if (file.bytes == null || file.bytes!.isEmpty) continue;

      final ext = file.extension?.toLowerCase() ?? '';
      final mimeType = switch (ext) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'svg' => 'image/svg+xml',
        _ => 'application/octet-stream',
      };

      bloc.add(
        AssetUploaded(
          projectId: projectId,
          name: file.name,
          mimeType: mimeType,
          data: file.bytes!,
        ),
      );
    }
  }
}

// =============================================================================
// Asset Grid Item (Draggable)
// =============================================================================

class _AssetGridItem extends StatelessWidget {
  const _AssetGridItem({
    required this.asset,
    this.cachedData,
  });

  final ProjectAsset asset;

  /// Full asset data from the cache, used as fallback preview
  /// when thumbnailBytes is not available.
  final Uint8List? cachedData;

  @override
  Widget build(BuildContext context) {
    return Draggable<ProjectAsset>(
      data: asset,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 64,
          height: 64,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            child: _buildThumbnail(context),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _buildContent(context),
      ),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: Tooltip(
        message: '${asset.name}\n${asset.width}×${asset.height} • '
            '${_formatFileSize(asset.fileSize)}',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(VioSpacing.radiusSm),
                  ),
                  child: _buildThumbnail(context),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 3,
                  ),
                  child: Text(
                    asset.name,
                    style: VioTypography.caption.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    // Priority: thumbnailBytes (from server) → cachedData (upload cache) → icon
    final bytes = asset.thumbnailBytes ?? cachedData;
    if (bytes != null && bytes.isNotEmpty) {
      return SizedBox.expand(
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildIconFallback(context),
          ),
        ),
      );
    }
    return _buildIconFallback(context);
  }

  Widget _buildIconFallback(BuildContext context) {
    return Center(
      child: Icon(
        asset.isSvg ? Icons.draw_outlined : Icons.image_outlined,
        size: 24,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        const PopupMenuItem(value: 'rename', child: Text('Rename')),
        const PopupMenuItem(value: 'move', child: Text('Move to group…')),
        PopupMenuItem(
          value: 'delete',
          child: Text(
            'Delete',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    ).then((value) {
      if (value == null || !context.mounted) return;
      switch (value) {
        case 'rename':
          _showRenameDialog(context);
        case 'move':
          _showMoveDialog(context);
        case 'delete':
          context.read<AssetBloc>().add(AssetDeleted(assetId: asset.id));
      }
    });
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: asset.name);
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: const Text('Rename Asset'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
          decoration: const InputDecoration(hintText: 'Asset name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    ).then((newName) {
      if (newName != null && newName.isNotEmpty && context.mounted) {
        context
            .read<AssetBloc>()
            .add(AssetRenamed(assetId: asset.id, newName: newName));
      }
    });
  }

  void _showMoveDialog(BuildContext context) {
    final controller = TextEditingController(text: asset.path);
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: const Text('Move to Group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
          decoration: const InputDecoration(
            hintText: 'Group path (e.g., Icons/Social)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Move'),
          ),
        ],
      ),
    ).then((newPath) {
      if (newPath != null && context.mounted) {
        context
            .read<AssetBloc>()
            .add(AssetMovedToGroup(assetId: asset.id, newPath: newPath));
      }
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// =============================================================================
// Asset List Item (Draggable)
// =============================================================================

class _AssetListItem extends StatelessWidget {
  const _AssetListItem({required this.asset});

  final ProjectAsset asset;

  @override
  Widget build(BuildContext context) {
    return Draggable<ProjectAsset>(
      data: asset,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: VioSpacing.sm,
            vertical: VioSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                asset.isSvg ? Icons.draw_outlined : Icons.image_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: VioSpacing.xs),
              Text(
                asset.name,
                style: VioTypography.body2
                    .copyWith(color: Theme.of(context).colorScheme.onSurface),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _buildContent(context),
      ),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: VioSpacing.sm),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            asset.isSvg ? Icons.draw_outlined : Icons.image_outlined,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: VioSpacing.xs),
          Expanded(
            child: Text(
              asset.name,
              style: VioTypography.body2.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${asset.width}×${asset.height}',
            style: VioTypography.caption.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Colors Section
// =============================================================================

class _ColorsSection extends StatelessWidget {
  const _ColorsSection({
    required this.colors,
    this.projectId,
  });

  final List<ProjectColor> colors;
  final String? projectId;

  @override
  Widget build(BuildContext context) {
    return VioPanel(
      title: 'Colors',
      collapsible: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${colors.length}',
            style: VioTypography.caption.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: VioSpacing.xs),
          VioIconButton(
            icon: Icons.add,
            size: 20,
            tooltip: 'Add color',
            onPressed: () => _addColor(context),
          ),
        ],
      ),
      child: colors.isEmpty
          ? AssetsTab._buildEmptyState(
              context,
              icon: Icons.palette_outlined,
              message: 'No colors\nClick + to add',
            )
          : _buildColorGrid(context),
    );
  }

  Widget _buildColorGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(VioSpacing.xs),
      child: Wrap(
        spacing: VioSpacing.xs,
        runSpacing: VioSpacing.xs,
        children: colors.map((color) => _ColorItem(color: color)).toList(),
      ),
    );
  }

  void _addColor(BuildContext context) {
    if (projectId == null) return;

    // Show color picker dialog
    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _AddColorDialog(projectId: projectId!),
    ).then((result) {
      if (result != null && context.mounted) {
        context.read<AssetBloc>().add(
              ColorCreated(
                projectId: projectId!,
                name: result['name'] as String,
                color: result['color'] as String?,
                opacity: (result['opacity'] as num?)?.toDouble() ?? 1.0,
              ),
            );
      }
    });
  }
}

// =============================================================================
// Color Item
// =============================================================================

class _ColorItem extends StatelessWidget {
  const _ColorItem({required this.color});

  final ProjectColor color;

  @override
  Widget build(BuildContext context) {
    return Draggable<ProjectColor>(
      data: color,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 32,
          height: 32,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _parseColor(),
              borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
          ),
        ),
      ),
      child: GestureDetector(
        onSecondaryTapUp: (details) =>
            _showContextMenu(context, details.globalPosition),
        onTap: () => _applyColor(context),
        child: Tooltip(
          message: '${color.name}\n${color.color ?? 'Gradient'}',
          child: SizedBox(
            width: 28,
            height: 28,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _parseColor(),
                gradient: color.isGradient ? _buildGradient() : null,
                borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _parseColor() {
    final value = color.colorValue;
    if (value != null) {
      return Color(value).withValues(alpha: color.opacity);
    }
    return Colors.grey;
  }

  LinearGradient? _buildGradient() {
    final g = color.gradient;
    if (g == null) return null;

    return LinearGradient(
      begin: Alignment(g.startX * 2 - 1, g.startY * 2 - 1),
      end: Alignment(g.endX * 2 - 1, g.endY * 2 - 1),
      colors: g.stops.map((s) {
        return Color(s.color).withValues(alpha: s.opacity);
      }).toList(),
      stops: g.stops.map((s) => s.offset).toList(),
    );
  }

  void _applyColor(BuildContext context) {
    final colorValue = color.colorValue;
    if (colorValue == null) return;

    // Apply this color to all selected shapes' fills
    final canvasBloc = context.read<CanvasBloc>();
    final selectedIds = canvasBloc.state.selectedShapeIds;
    if (selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a shape first'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    final newFill = ShapeFill(
      color: colorValue,
      opacity: color.opacity,
    );

    for (final shapeId in selectedIds) {
      final shape = canvasBloc.state.shapes[shapeId];
      if (shape == null) continue;

      final updatedShape = shape.copyWith(fills: [newFill]);
      canvasBloc.add(ShapeUpdated(updatedShape));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Applied "${color.name}" to ${selectedIds.length} shape(s)'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        const PopupMenuItem(value: 'edit', child: Text('Edit color')),
        const PopupMenuItem(value: 'rename', child: Text('Rename')),
        const PopupMenuItem(value: 'move', child: Text('Move to group…')),
        PopupMenuItem(
          value: 'delete',
          child: Text(
            'Delete',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    ).then((value) {
      if (value == null || !context.mounted) return;
      switch (value) {
        case 'edit':
          _showEditDialog(context);
        case 'rename':
          _showRenameDialog(context);
        case 'move':
          _showMoveDialog(context);
        case 'delete':
          context.read<AssetBloc>().add(ColorDeleted(colorId: color.id));
      }
    });
  }

  void _showEditDialog(BuildContext context) {
    final colorController = TextEditingController(text: color.color ?? '');
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: const Text('Edit Color'),
        content: TextField(
          controller: colorController,
          autofocus: true,
          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
          decoration:
              const InputDecoration(hintText: 'Hex color (e.g., #4C9AFF)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, colorController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((newColor) {
      if (newColor != null && newColor.isNotEmpty && context.mounted) {
        context.read<AssetBloc>().add(
              ColorUpdated(colorId: color.id, color: newColor),
            );
      }
    });
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: color.name);
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: const Text('Rename Color'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
          decoration: const InputDecoration(hintText: 'Color name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    ).then((newName) {
      if (newName != null && newName.isNotEmpty && context.mounted) {
        context.read<AssetBloc>().add(
              ColorUpdated(colorId: color.id, name: newName),
            );
      }
    });
  }

  void _showMoveDialog(BuildContext context) {
    final controller = TextEditingController(text: color.path);
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: const Text('Move to Group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
          decoration: const InputDecoration(
            hintText: 'Group path (e.g., Brand/Primary)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Move'),
          ),
        ],
      ),
    ).then((newPath) {
      if (newPath != null && context.mounted) {
        context.read<AssetBloc>().add(
              ColorUpdated(colorId: color.id, path: newPath),
            );
      }
    });
  }
}

// =============================================================================
// Add Color Dialog
// =============================================================================

class _AddColorDialog extends StatefulWidget {
  const _AddColorDialog({required this.projectId});

  final String projectId;

  @override
  State<_AddColorDialog> createState() => _AddColorDialogState();
}

class _AddColorDialogState extends State<_AddColorDialog> {
  final _nameController = TextEditingController(text: 'New Color');
  final _colorController = TextEditingController(text: '#4C9AFF');
  Color _previewColor = const Color(0xFF4C9AFF);

  @override
  void dispose() {
    _nameController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  void _updatePreview() {
    final hex = _colorController.text.replaceFirst('#', '');
    if (hex.length == 6) {
      final value = int.tryParse('FF$hex', radix: 16);
      if (value != null) {
        setState(() => _previewColor = Color(value));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: const Text('Add Color'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Color preview
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(bottom: VioSpacing.md),
            decoration: BoxDecoration(
              color: _previewColor,
              borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          // Name
          TextField(
            controller: _nameController,
            autofocus: true,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: VioSpacing.sm),
          // Hex color
          TextField(
            controller: _colorController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: const InputDecoration(labelText: 'Hex color'),
            onChanged: (_) => _updatePreview(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, {
              'name': _nameController.text,
              'color': _colorController.text,
              'opacity': 1.0,
            });
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
