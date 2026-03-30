import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_client/src/features/version_control/bloc/version_control_bloc.dart';
import 'package:vio_client/src/features/workspace/bloc/search_bloc.dart';
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

  void _onQueryChanged() {
    if (!mounted) return;
    context.read<SearchBloc>().add(SearchQueryChanged(_controller.text));
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onQueryChanged);

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
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final searchState = context.watch<SearchBloc>().state;

    final layerResults = searchState.layerResults
        .map(
          (result) => _SearchResultItem(
            title: result.title,
            subtitle: result.subtitle,
            icon: _iconForShapeType(result.shapeType),
            onTap: () {
              widget.onLayerResultTap(shapeId: result.shapeId);
            },
            onHoverChanged: (isHovering) {
              widget.onLayerResultHoverChanged(
                isHovering ? result.shapeId : null,
              );
            },
          ),
        )
        .toList(growable: false);

    final assetResults = searchState.assetResults
        .map(
          (result) => _SearchResultItem(
            title: result.title,
            subtitle: result.subtitle,
            icon: result.isSvg
                ? Icons.data_object_outlined
                : Icons.image_outlined,
          ),
        )
        .toList(growable: false);

    final colorResults = searchState.colorResults
        .map(
          (result) => _SearchResultItem(
            title: result.title,
            subtitle: result.subtitle,
            icon: Icons.palette_outlined,
          ),
        )
        .toList(growable: false);

    final branchResults = searchState.branchResults
        .map(
          (result) => _SearchResultItem(
            title: result.title,
            subtitle: result.subtitle,
            icon: Icons.account_tree_outlined,
          ),
        )
        .toList(growable: false);

    final commitResults = searchState.commitResults
        .map(
          (result) => _SearchResultItem(
            title: result.title,
            subtitle: result.subtitle,
            icon: Icons.history_outlined,
          ),
        )
        .toList(growable: false);

    final pullRequestResults = searchState.pullRequestResults
        .map(
          (result) => _SearchResultItem(
            title: result.title,
            subtitle: result.subtitle,
            icon: Icons.merge_type_outlined,
          ),
        )
        .toList(growable: false);

    final totalResults = searchState.totalResults;

    return Column(
      children: [
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: VioSpacing.xs),
          child: VioSearchBar(
            controller: _controller,
            hintText: 'Search workspace…',
          ),
        ),
        Expanded(
          child: !searchState.hasQuery
              ? const _EmptySearchState()
              : searchState.status == SearchStatus.searching &&
                      totalResults == 0
                  ? const _SearchingState()
                  : totalResults == 0
                      ? const _NoResultsState()
                      : ListView(
                          padding: const EdgeInsets.symmetric(
                              vertical: VioSpacing.xs,),
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

  IconData _iconForShapeType(ShapeType shapeType) => switch (shapeType) {
        ShapeType.rectangle => Icons.crop_square_outlined,
        ShapeType.ellipse => Icons.circle_outlined,
        ShapeType.frame => Icons.crop_free_outlined,
        ShapeType.text => Icons.text_fields_outlined,
        ShapeType.group => Icons.folder_outlined,
        ShapeType.path => Icons.draw_outlined,
        ShapeType.image || ShapeType.svg => Icons.image_outlined,
        ShapeType.bool => Icons.auto_fix_normal_outlined
      };
}

class _SearchMetaRow extends StatelessWidget {
  const _SearchMetaRow({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: VioSpacing.sm,
          vertical: VioSpacing.xs,
        ),
        child: Text(
          '$total result${total == 1 ? '' : 's'}',
          style: VioTypography.caption
              .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
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
    final cs = Theme.of(context).colorScheme;
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
              Icon(icon, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: VioSpacing.xs),
              Text(
                title,
                style:
                    VioTypography.caption.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: VioSpacing.xs),
              Text(
                '${items.length}',
                style:
                    VioTypography.caption.copyWith(color: cs.onSurfaceVariant),
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
    final cs = Theme.of(context).colorScheme;
    final content = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VioSpacing.sm,
        vertical: VioSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(item.icon, size: 14, color: cs.onSurfaceVariant),
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
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VioTypography.caption.copyWith(
                    color: cs.onSurfaceVariant,
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
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VioSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.manage_search_outlined,
              size: 28,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: VioSpacing.sm),
            Text(
              'Search layers, assets, colors, branches, commits, and pull requests',
              textAlign: TextAlign.center,
              style: VioTypography.body2.copyWith(
                color: cs.onSurfaceVariant,
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
  Widget build(BuildContext context) => Center(
        child: Text(
          'No results found',
          style: VioTypography.body2.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
}

class _SearchingState extends StatelessWidget {
  const _SearchingState();

  @override
  Widget build(BuildContext context) => Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
}
