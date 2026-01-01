import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_core/vio_core.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../bloc/canvas_bloc.dart';
import 'layer_item.dart';

/// Displays the hierarchical layer tree
class LayerTree extends StatelessWidget {
  const LayerTree({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CanvasBloc, CanvasState>(
      builder: (context, state) {
        if (state.shapes.isEmpty) {
          return const _EmptyState();
        }

        final tree = LayerTreeBuilder.buildTree(state.shapes);

        return ListView.builder(
          itemCount: _countVisibleNodes(tree, state.expandedLayerIds),
          itemBuilder: (context, index) {
            final (node, _) =
                _getNodeAtIndex(tree, index, state.expandedLayerIds);
            if (node == null) return const SizedBox.shrink();

            return LayerItem(
              key: ValueKey(node.shape.id),
              shape: node.shape,
              depth: node.depth,
              isExpanded: state.expandedLayerIds.contains(node.shape.id),
              hasChildren: node.hasChildren,
              isSelected: state.selectedShapeIds.contains(node.shape.id),
              isHovered: state.hoveredLayerId == node.shape.id ||
                  state.hoveredShapeId == node.shape.id,
            );
          },
        );
      },
    );
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
