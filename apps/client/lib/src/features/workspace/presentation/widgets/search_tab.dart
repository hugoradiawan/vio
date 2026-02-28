import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_client/src/features/assets/bloc/asset_bloc.dart';
import 'package:vio_client/src/features/canvas/bloc/canvas_bloc.dart';
import 'package:vio_client/src/features/version_control/bloc/version_control_bloc.dart';
import 'package:vio_core/vio_core.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

typedef LayerResultTap = void Function({
  required String shapeId,
});

typedef LayerResultHoverChanged = void Function(String? shapeId);

class SearchTab extends StatefulWidget {
  const SearchTab({
    required this.onLayerResultTap,
    required this.onLayerResultHoverChanged,
    super.key,
  });

  final LayerResultTap onLayerResultTap;
  final LayerResultHoverChanged onLayerResultHoverChanged;

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab>
    with AutomaticKeepAliveClientMixin<SearchTab> {
  late final TextEditingController _controller;

  String get _query => _controller.text.trim();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context
          .read<VersionControlBloc>()
          .add(const PullRequestsRefreshRequested());
    });
  }

  @override
  void dispose() {
    widget.onLayerResultHoverChanged(null);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final normalizedQuery = _query.toLowerCase();
    final canvasState = context.watch<CanvasBloc>().state;
    final assetState = context.watch<AssetBloc>().state;
    final versionState = context.watch<VersionControlBloc>().state;

    final layerResults = normalizedQuery.isEmpty
        ? const <_SearchResultItem>[]
        : canvasState.shapeList
            .where(
              (shape) => _matches(
                normalizedQuery,
                [shape.name, shape.type.name, shape.id],
              ),
            )
            .take(30)
            .map(
              (shape) => _SearchResultItem(
                title: shape.name.isEmpty
                    ? 'Untitled ${shape.type.name}'
                    : shape.name,
                subtitle: '${shape.type.name} · ${shape.id}',
                icon: _iconForShape(shape),
                onTap: () {
                  widget.onLayerResultTap(
                    shapeId: shape.id,
                  );
                },
                onHoverChanged: (isHovering) {
                  widget.onLayerResultHoverChanged(
                    isHovering ? shape.id : null,
                  );
                },
              ),
            )
            .toList(growable: false);

    final assetResults = normalizedQuery.isEmpty
        ? const <_SearchResultItem>[]
        : assetState.assets
            .where(
              (asset) => _matches(
                normalizedQuery,
                [asset.name, asset.path, asset.mimeType, asset.id],
              ),
            )
            .take(30)
            .map(
              (asset) => _SearchResultItem(
                title: asset.name,
                subtitle: asset.path.isEmpty
                    ? asset.mimeType
                    : '${asset.path} · ${asset.mimeType}',
                icon: asset.isSvg
                    ? Icons.data_object_outlined
                    : Icons.image_outlined,
              ),
            )
            .toList(growable: false);

    final colorResults = normalizedQuery.isEmpty
        ? const <_SearchResultItem>[]
        : assetState.colors
            .where(
              (color) => _matches(
                normalizedQuery,
                [color.name, color.path, color.color, color.id],
              ),
            )
            .take(30)
            .map(
              (color) => _SearchResultItem(
                title: color.name,
                subtitle: color.path.isEmpty
                    ? (color.color ?? 'Gradient')
                    : '${color.path} · ${color.color ?? 'Gradient'}',
                icon: Icons.palette_outlined,
              ),
            )
            .toList(growable: false);

    final branchResults = normalizedQuery.isEmpty
        ? const <_SearchResultItem>[]
        : versionState.branches
            .where(
              (branch) => _matches(
                normalizedQuery,
                [branch.name, branch.description, branch.id],
              ),
            )
            .take(30)
            .map(
              (branch) => _SearchResultItem(
                title: branch.name,
                subtitle: branch.description.isEmpty
                    ? branch.id
                    : '${branch.description} · ${branch.id}',
                icon: Icons.account_tree_outlined,
              ),
            )
            .toList(growable: false);

    final commitResults = normalizedQuery.isEmpty
        ? const <_SearchResultItem>[]
        : versionState.commits
            .where(
              (commit) => _matches(
                normalizedQuery,
                [commit.message, commit.authorId, commit.id, commit.branchId],
              ),
            )
            .take(30)
            .map(
              (commit) => _SearchResultItem(
                title: commit.message,
                subtitle: '${commit.authorId} · ${commit.id}',
                icon: Icons.history_outlined,
              ),
            )
            .toList(growable: false);

    final pullRequestResults = normalizedQuery.isEmpty
        ? const <_SearchResultItem>[]
        : versionState.pullRequests
            .where(
              (pullRequest) => _matches(
                normalizedQuery,
                [
                  pullRequest.title,
                  pullRequest.description,
                  pullRequest.id,
                  pullRequest.sourceBranchId,
                  pullRequest.targetBranchId,
                ],
              ),
            )
            .take(30)
            .map(
              (pullRequest) => _SearchResultItem(
                title: pullRequest.title,
                subtitle:
                    '${_enumName(pullRequest.status)} · ${pullRequest.sourceBranchId} → ${pullRequest.targetBranchId}',
                icon: Icons.merge_type_outlined,
              ),
            )
            .toList(growable: false);

    final totalResults = layerResults.length +
        assetResults.length +
        colorResults.length +
        branchResults.length +
        commitResults.length +
        pullRequestResults.length;

    return Column(
      children: [
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: VioSpacing.xs),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: VioColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: VioTypography.body2
                      .copyWith(color: VioColors.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search workspace…',
                    hintStyle: VioTypography.body2
                        .copyWith(color: VioColors.textTertiary),
                    border: InputBorder.none,
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 16,
                      color: VioColors.textTertiary,
                    ),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 24, minHeight: 16),
                  ),
                ),
              ),
              if (_query.isNotEmpty)
                VioIconButton(
                  icon: Icons.close,
                  size: 24,
                  tooltip: 'Clear search',
                  onPressed: _controller.clear,
                ),
            ],
          ),
        ),
        Expanded(
          child: _query.isEmpty
              ? const _EmptySearchState()
              : totalResults == 0
                  ? const _NoResultsState()
                  : ListView(
                      padding:
                          const EdgeInsets.symmetric(vertical: VioSpacing.xs),
                      children: [
                        _SearchMetaRow(total: totalResults),
                        _SearchSection(
                          title: 'Layers',
                          icon: Icons.layers_outlined,
                          items: layerResults,
                        ),
                        _SearchSection(
                          title: 'Assets',
                          icon: Icons.perm_media_outlined,
                          items: assetResults,
                        ),
                        _SearchSection(
                          title: 'Colors',
                          icon: Icons.palette_outlined,
                          items: colorResults,
                        ),
                        _SearchSection(
                          title: 'Branches',
                          icon: Icons.account_tree_outlined,
                          items: branchResults,
                        ),
                        _SearchSection(
                          title: 'Commits',
                          icon: Icons.history_outlined,
                          items: commitResults,
                        ),
                        _SearchSection(
                          title: 'Pull Requests',
                          icon: Icons.merge_type_outlined,
                          items: pullRequestResults,
                        ),
                      ],
                    ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;

  bool _matches(String query, List<String?> values) {
    if (query.isEmpty) return true;
    return values.any((value) => (value ?? '').toLowerCase().contains(query));
  }

  IconData _iconForShape(Shape shape) {
    switch (shape.type) {
      case ShapeType.rectangle:
        return Icons.crop_square_outlined;
      case ShapeType.ellipse:
        return Icons.circle_outlined;
      case ShapeType.frame:
        return Icons.crop_free_outlined;
      case ShapeType.text:
        return Icons.text_fields_outlined;
      case ShapeType.group:
        return Icons.folder_outlined;
      case ShapeType.path:
        return Icons.draw_outlined;
      case ShapeType.image:
      case ShapeType.svg:
        return Icons.image_outlined;
      case ShapeType.bool:
        return Icons.auto_fix_normal_outlined;
    }
  }

  String _enumName(Object enumValue) {
    final raw = enumValue.toString();
    final dotIndex = raw.lastIndexOf('.');
    return dotIndex >= 0 ? raw.substring(dotIndex + 1) : raw;
  }
}

class _SearchMetaRow extends StatelessWidget {
  const _SearchMetaRow({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VioSpacing.sm,
        vertical: VioSpacing.xs,
      ),
      child: Text(
        '$total result${total == 1 ? '' : 's'}',
        style: VioTypography.caption.copyWith(color: VioColors.textTertiary),
      ),
    );
  }
}

class _SearchSection extends StatelessWidget {
  const _SearchSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<_SearchResultItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            VioSpacing.sm,
            VioSpacing.sm,
            VioSpacing.sm,
            VioSpacing.xs,
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: VioColors.textTertiary),
              const SizedBox(width: VioSpacing.xs),
              Text(
                title,
                style: VioTypography.caption
                    .copyWith(color: VioColors.textTertiary),
              ),
              const SizedBox(width: VioSpacing.xs),
              Text(
                '${items.length}',
                style: VioTypography.caption
                    .copyWith(color: VioColors.textTertiary),
              ),
            ],
          ),
        ),
        ...items.map((item) => _SearchResultTile(item: item)),
      ],
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.item});

  final _SearchResultItem item;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VioSpacing.sm,
        vertical: VioSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(item.icon, size: 14, color: VioColors.textSecondary),
          const SizedBox(width: VioSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VioTypography.body2.copyWith(
                    color: VioColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VioTypography.caption.copyWith(
                    color: VioColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (item.onTap == null) {
      if (item.onHoverChanged == null) {
        return content;
      }

      return MouseRegion(
        onEnter: (_) => item.onHoverChanged!(true),
        onExit: (_) => item.onHoverChanged!(false),
        child: content,
      );
    }

    final tappableContent = InkWell(onTap: item.onTap, child: content);
    if (item.onHoverChanged == null) {
      return tappableContent;
    }

    return MouseRegion(
      onEnter: (_) => item.onHoverChanged!(true),
      onExit: (_) => item.onHoverChanged!(false),
      child: tappableContent,
    );
  }
}

class _SearchResultItem {
  const _SearchResultItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.onHoverChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onHoverChanged;
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VioSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.manage_search_outlined,
              size: 28,
              color: VioColors.textTertiary,
            ),
            const SizedBox(height: VioSpacing.sm),
            Text(
              'Search layers, assets, colors, branches, commits, and pull requests',
              textAlign: TextAlign.center,
              style: VioTypography.body2.copyWith(
                color: VioColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No results found',
        style: VioTypography.body2.copyWith(
          color: VioColors.textTertiary,
        ),
      ),
    );
  }
}
