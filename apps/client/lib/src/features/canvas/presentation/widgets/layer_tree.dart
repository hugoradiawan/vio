import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_core/vio_core.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../bloc/canvas_bloc.dart';
import 'layer_item.dart';

class _LayerDragPayload {
  const _LayerDragPayload(this.shapeIds);
  final List<String> shapeIds;
}

/// Displays the hierarchical layer tree
class LayerTree extends StatelessWidget {
  const LayerTree({
    super.key,
    this.searchQuery = '',
    this.searchOpen = false,
  });

  final String searchQuery;
  final bool searchOpen;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CanvasBloc, CanvasState>(
      builder: (context, state) {
        if (state.shapes.isEmpty) {
          return const _EmptyState();
        }

        final tree = LayerTreeBuilder.buildTree(state.shapes);

        final normalizedQuery = searchQuery.trim().toLowerCase();
        final isSearching = searchOpen && normalizedQuery.isNotEmpty;

        final visibleTree =
            isSearching ? _filterTree(tree, normalizedQuery) : tree;

        final effectiveExpandedIds = isSearching
            ? _collectExpandableIds(visibleTree)
            : state.expandedLayerIds;

        List<String> reparentableIds(List<String> ids) {
          final out = <String>[];
          for (final id in ids) {
            final shape = state.shapes[id];
            if (shape == null) continue;
            if (shape is FrameShape) continue;
            if (shape.blocked) continue;
            out.add(id);
          }
          return out;
        }

        Widget buildLayerRow(LayerNode node, bool isDropTargetActive) {
          final isSelected = state.selectedShapeIds.contains(node.shape.id);
          final dragIds =
              isSelected ? state.selectedShapeIds : <String>[node.shape.id];
          final payload = _LayerDragPayload(dragIds);

          final row = LayerItem(
            key: ValueKey(node.shape.id),
            shape: node.shape,
            depth: node.depth,
            isExpanded: state.expandedLayerIds.contains(node.shape.id),
            hasChildren: node.hasChildren,
            isSelected: isSelected,
            isHovered: state.hoveredLayerId == node.shape.id ||
                state.hoveredShapeId == node.shape.id,
          );

          return Draggable<_LayerDragPayload>(
            data: payload,
            feedback: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Opacity(opacity: 0.9, child: row),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.35, child: row),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: isDropTargetActive
                    ? Border.all(
                        color: VioColors.primary.withValues(alpha: 0.8),
                      )
                    : null,
                color: isDropTargetActive
                    ? VioColors.primary.withValues(alpha: 0.06)
                    : null,
              ),
              child: row,
            ),
          );
        }

        return DragTarget<_LayerDragPayload>(
          onWillAcceptWithDetails: (details) {
            // Root drop target: accept any drag to reparent to root.
            return reparentableIds(details.data.shapeIds).isNotEmpty;
          },
          onAcceptWithDetails: (details) {
            final ids = reparentableIds(details.data.shapeIds);
            if (ids.isEmpty) return;
            context.read<CanvasBloc>().add(
                  ShapesReparented(
                    shapeIds: ids,
                    destinationFrameId: null,
                  ),
                );
          },
          builder: (context, candidateData, rejectedData) {
            return ListView.builder(
              itemCount: _countVisibleNodes(visibleTree, effectiveExpandedIds),
              itemBuilder: (context, index) {
                final (node, _) =
                    _getNodeAtIndex(visibleTree, index, effectiveExpandedIds);
                if (node == null) return const SizedBox.shrink();

                final isFrame = node.shape is FrameShape;

                return DragTarget<_LayerDragPayload>(
                  onWillAcceptWithDetails: (details) {
                    if (!isFrame) return false;
                    final ids = reparentableIds(details.data.shapeIds);
                    if (ids.isEmpty) return false;
                    // Don't allow dropping a selection onto itself.
                    if (ids.contains(node.shape.id)) {
                      return false;
                    }
                    return true;
                  },
                  onAcceptWithDetails: (details) {
                    final ids = reparentableIds(details.data.shapeIds);
                    if (ids.isEmpty) return;
                    context.read<CanvasBloc>().add(
                          ShapesReparented(
                            shapeIds: ids,
                            destinationFrameId: node.shape.id,
                          ),
                        );
                  },
                  builder: (context, candidate, rejected) {
                    return buildLayerRow(node, candidate.isNotEmpty);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  List<LayerNode> _filterTree(List<LayerNode> nodes, String query) {
    final out = <LayerNode>[];

    for (final node in nodes) {
      final name = node.shape.name.toLowerCase();
      final selfMatches = name.contains(query);

      final filteredChildren = node.hasChildren
          ? _filterTree(node.children, query)
          : const <LayerNode>[];

      if (selfMatches || filteredChildren.isNotEmpty) {
        out.add(
          LayerNode(
            shape: node.shape,
            children: filteredChildren,
            depth: node.depth,
          ),
        );
      }
    }

    return out;
  }

  Set<String> _collectExpandableIds(List<LayerNode> nodes) {
    final expanded = <String>{};

    void visit(List<LayerNode> list) {
      for (final node in list) {
        if (node.hasChildren) {
          expanded.add(node.shape.id);
          visit(node.children);
        }
      }
    }

    visit(nodes);
    return expanded;
  }

  /// Count total visible nodes (considering expanded/collapsed state)
  int _countVisibleNodes(List<LayerNode> nodes, Set<String> expandedIds) {
    int count = 0;
    for (final node in nodes) {
      count++; // Count this node
      if (expandedIds.contains(node.shape.id) && node.hasChildren) {
        count += _countVisibleNodes(node.children, expandedIds);
      }
    }
    return count;
  }

  /// Get the node at a specific flattened index
  (LayerNode?, int) _getNodeAtIndex(
    List<LayerNode> nodes,
    int targetIndex,
    Set<String> expandedIds,
  ) {
    int currentIndex = 0;

    for (final node in nodes) {
      if (currentIndex == targetIndex) {
        return (node, currentIndex);
      }
      currentIndex++;

      if (expandedIds.contains(node.shape.id) && node.hasChildren) {
        final childCount = _countVisibleNodes(node.children, expandedIds);
        if (targetIndex < currentIndex + childCount) {
          // Target is in this subtree
          return _getNodeAtIndex(
            node.children,
            targetIndex - currentIndex,
            expandedIds,
          );
        }
        currentIndex += childCount;
      }
    }

    return (null, currentIndex);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.layers_outlined,
            size: 48,
            color: VioColors.textDisabled,
          ),
          SizedBox(height: 16),
          Text(
            'No layers yet',
            style: TextStyle(
              color: VioColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Draw a shape to get started',
            style: TextStyle(
              color: VioColors.textDisabled,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
