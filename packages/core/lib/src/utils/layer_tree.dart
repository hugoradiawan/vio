import 'package:vio_core/vio_core.dart';

/// Represents a node in the layer tree hierarchy
class LayerNode {
  const LayerNode({
    required this.shape,
    this.children = const [],
    this.depth = 0,
  });

  /// The shape this node represents
  final Shape shape;

  /// Child nodes (for frames/groups)
  final List<LayerNode> children;

  /// Depth level in the tree (0 = root)
  final int depth;

  /// Whether this node can have children (is a container)
  bool get isContainer =>
      shape.type == ShapeType.frame || shape.type == ShapeType.group;

  /// Whether this node has any children
  bool get hasChildren => children.isNotEmpty;
}

/// Utility class to build a hierarchical layer tree from a flat shape map
class LayerTreeBuilder {
  const LayerTreeBuilder._();

  /// Build a layer tree from a flat map of shapes
  ///
  /// Returns root-level nodes in display order (top to bottom in layers panel,
  /// which corresponds to back-to-front in z-order on canvas).
  static List<LayerNode> buildTree(Map<String, Shape> shapes) {
    if (shapes.isEmpty) return [];

    // Find root shapes (no parentId and no frameId, OR frameId but frame doesn't exist)
    // and shapes directly inside frames
    final rootShapes = <Shape>[];
    final childrenByParent = <String, List<Shape>>{};

    for (final shape in shapes.values) {
      final parentId = shape.parentId ?? shape.frameId;

      if (parentId == null || !shapes.containsKey(parentId)) {
        // This is a root-level shape
        rootShapes.add(shape);
      } else {
        // This shape has a parent
        childrenByParent.putIfAbsent(parentId, () => []).add(shape);
      }
    }

    // Sort root shapes by z-order (frames first, then by some order)
    // For now, sort by type (frames first) then by name
    rootShapes.sort(_compareShapesForDisplay);

    // Build tree recursively
    return rootShapes.reversed
        .map((shape) => _buildNode(shape, childrenByParent, 0))
        .toList();
  }

  /// Build a single node and its children recursively
  static LayerNode _buildNode(
    Shape shape,
    Map<String, List<Shape>> childrenByParent,
    int depth,
  ) {
    final childShapes = childrenByParent[shape.id] ?? [];

    // Sort children for display
    childShapes.sort(_compareShapesForDisplay);

    // Build child nodes (reversed for display order: top-to-bottom = back-to-front)
    final childNodes = childShapes.reversed
        .map((child) => _buildNode(child, childrenByParent, depth + 1))
        .toList();

    return LayerNode(
      shape: shape,
      children: childNodes,
      depth: depth,
    );
  }

  /// Compare shapes for display ordering
  /// Frames come first, then other shapes sorted by name
  static int _compareShapesForDisplay(Shape a, Shape b) {
    // Frames should appear at the top level
    if (a.type == ShapeType.frame && b.type != ShapeType.frame) return -1;
    if (b.type == ShapeType.frame && a.type != ShapeType.frame) return 1;

    // Otherwise sort by name
    return a.name.compareTo(b.name);
  }

  /// Get the children of a specific shape in display order
  static List<Shape> getChildren(String parentId, Map<String, Shape> shapes) {
    final children = shapes.values
        .where((s) => s.parentId == parentId || s.frameId == parentId)
        .toList();

    children.sort(_compareShapesForDisplay);
    return children.reversed.toList();
  }

  /// Check if a shape is a container (can have children)
  static bool isContainer(Shape shape) {
    return shape.type == ShapeType.frame || shape.type == ShapeType.group;
  }

  /// Get all ancestor IDs of a shape (for expand-to-selection feature)
  static List<String> getAncestorIds(
    String shapeId,
    Map<String, Shape> shapes,
  ) {
    final ancestors = <String>[];
    var currentId = shapeId;

    while (true) {
      final shape = shapes[currentId];
      if (shape == null) break;

      final parentId = shape.parentId ?? shape.frameId;
      if (parentId == null || !shapes.containsKey(parentId)) break;

      ancestors.add(parentId);
      currentId = parentId;
    }

    return ancestors;
  }
}
