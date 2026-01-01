import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:vio_core/vio_core.dart';

/// Configuration for snap behavior
class SnapConfig {
  const SnapConfig({
    this.pointSnapThreshold = 10.0,
    this.distanceSnapThreshold = 20.0,
    this.enabled = true,
    this.snapToFrameEdges = true,
    this.snapToFrameCenter = true,
    this.snapToShapeEdges = true,
    this.snapToShapeCenter = true,
    this.snapToGrid = true,
  });

  /// Threshold in pixels for point snapping (scaled by 1/zoom)
  final double pointSnapThreshold;

  /// Threshold in pixels for distance snapping
  final double distanceSnapThreshold;

  /// Whether snapping is enabled
  final bool enabled;

  /// Snap to frame edges (left, right, top, bottom)
  final bool snapToFrameEdges;

  /// Snap to frame center (horizontal and vertical)
  final bool snapToFrameCenter;

  /// Snap to other shape edges
  final bool snapToShapeEdges;

  /// Snap to other shape centers
  final bool snapToShapeCenter;

  /// Snap to grid lines
  final bool snapToGrid;

  /// Get effective threshold based on zoom level
  double getEffectiveThreshold(double zoom) => pointSnapThreshold / zoom;
}

/// Type of snap point
enum SnapPointType {
  /// Corner of a shape (top-left, top-right, bottom-left, bottom-right)
  corner,

  /// Center of a shape
  center,

  /// Midpoint of an edge (top-center, right-center, bottom-center, left-center)
  edgeMidpoint,

  /// Frame edge (entire line, not just a point)
  frameEdge,

  /// Grid line
  grid,

  /// User-created guide
  guide,
}

/// Axis for snap alignment
enum SnapAxis {
  /// Horizontal alignment (same X coordinate)
  horizontal,

  /// Vertical alignment (same Y coordinate)
  vertical,

  /// Both axes
  both,
}

/// Represents a snap point that shapes can snap to
class SnapPoint {
  const SnapPoint({
    required this.x,
    required this.y,
    required this.type,
    required this.axis,
    this.sourceId,
    this.sourceName,
  });

  /// X coordinate of the snap point
  final double x;

  /// Y coordinate of the snap point
  final double y;

  /// Type of snap point
  final SnapPointType type;

  /// Which axis this point provides snapping for
  final SnapAxis axis;

  /// ID of the shape/frame that generated this snap point
  final String? sourceId;

  /// Name of the source (for debugging/display)
  final String? sourceName;

  /// Get the coordinate for a specific axis
  double getCoordinate(SnapAxis forAxis) {
    return forAxis == SnapAxis.horizontal ? x : y;
  }

  Offset get point => Offset(x, y);

  @override
  String toString() =>
      'SnapPoint($x, $y, $type, $axis, source: $sourceId)';
}

/// Represents a snap line to be drawn
class SnapLine {
  const SnapLine({
    required this.start,
    required this.end,
    required this.axis,
    this.isCenter = false,
  });

  /// Start point of the line
  final Offset start;

  /// End point of the line
  final Offset end;

  /// Axis of the snap line
  final SnapAxis axis;

  /// Whether this is a center alignment line
  final bool isCenter;
}

/// Result of a snap detection operation
class SnapResult {
  const SnapResult({
    this.snapX,
    this.snapY,
    this.deltaX = 0,
    this.deltaY = 0,
    this.snapPoints = const [],
    this.snapLines = const [],
  });

  /// The snap point matched on X axis
  final SnapPoint? snapX;

  /// The snap point matched on Y axis
  final SnapPoint? snapY;

  /// Delta to apply to X to achieve snap
  final double deltaX;

  /// Delta to apply to Y to achieve snap
  final double deltaY;

  /// All snap points that matched
  final List<SnapPoint> snapPoints;

  /// Lines to draw showing snap alignment
  final List<SnapLine> snapLines;

  /// Whether any snap was found
  bool get hasSnap => snapX != null || snapY != null;

  /// Combined snap offset to apply
  Offset get snapOffset => Offset(deltaX, deltaY);

  /// Create empty result
  static const empty = SnapResult();
}

/// Generates snap points from shapes and frames
class SnapPointGenerator {
  const SnapPointGenerator._();

  /// Generate snap points from a shape's bounds
  static List<SnapPoint> fromShape(Shape shape, {bool includeCenter = true}) {
    final bounds = shape.bounds;
    final points = <SnapPoint>[];

    // Transform bounds corners through shape transform
    final topLeft = shape.transformPoint(Offset(bounds.left, bounds.top));
    final topRight = shape.transformPoint(Offset(bounds.right, bounds.top));
    final bottomLeft = shape.transformPoint(Offset(bounds.left, bounds.bottom));
    final bottomRight =
        shape.transformPoint(Offset(bounds.right, bounds.bottom));
    // Corner points (snap on both axes)
    points.addAll([
      SnapPoint(
        x: topLeft.dx,
        y: topLeft.dy,
        type: SnapPointType.corner,
        axis: SnapAxis.both,
        sourceId: shape.id,
        sourceName: shape.name,
      ),
      SnapPoint(
        x: topRight.dx,
        y: topRight.dy,
        type: SnapPointType.corner,
        axis: SnapAxis.both,
        sourceId: shape.id,
        sourceName: shape.name,
      ),
      SnapPoint(
        x: bottomLeft.dx,
        y: bottomLeft.dy,
        type: SnapPointType.corner,
        axis: SnapAxis.both,
        sourceId: shape.id,
        sourceName: shape.name,
      ),
      SnapPoint(
        x: bottomRight.dx,
        y: bottomRight.dy,
        type: SnapPointType.corner,
        axis: SnapAxis.both,
        sourceId: shape.id,
        sourceName: shape.name,
      ),
    ]);

    // Edge midpoints
    final topCenter = Offset(
      (topLeft.dx + topRight.dx) / 2,
      (topLeft.dy + topRight.dy) / 2,
    );
    final bottomCenter = Offset(
      (bottomLeft.dx + bottomRight.dx) / 2,
      (bottomLeft.dy + bottomRight.dy) / 2,
    );
    final leftCenter = Offset(
      (topLeft.dx + bottomLeft.dx) / 2,
      (topLeft.dy + bottomLeft.dy) / 2,
    );
    final rightCenter = Offset(
      (topRight.dx + bottomRight.dx) / 2,
      (topRight.dy + bottomRight.dy) / 2,
    );

    points.addAll([
      SnapPoint(
        x: topCenter.dx,
        y: topCenter.dy,
        type: SnapPointType.edgeMidpoint,
        axis: SnapAxis.horizontal, // Primarily for X alignment
        sourceId: shape.id,
        sourceName: shape.name,
      ),
      SnapPoint(
        x: bottomCenter.dx,
        y: bottomCenter.dy,
        type: SnapPointType.edgeMidpoint,
        axis: SnapAxis.horizontal,
        sourceId: shape.id,
        sourceName: shape.name,
      ),
      SnapPoint(
        x: leftCenter.dx,
        y: leftCenter.dy,
        type: SnapPointType.edgeMidpoint,
        axis: SnapAxis.vertical, // Primarily for Y alignment
        sourceId: shape.id,
        sourceName: shape.name,
      ),
      SnapPoint(
        x: rightCenter.dx,
        y: rightCenter.dy,
        type: SnapPointType.edgeMidpoint,
        axis: SnapAxis.vertical,
        sourceId: shape.id,
        sourceName: shape.name,
      ),
    ]);

    // Center point
    if (includeCenter) {
      final center = Offset(
        (topLeft.dx + bottomRight.dx) / 2,
        (topLeft.dy + bottomRight.dy) / 2,
      );
      points.add(
        SnapPoint(
          x: center.dx,
          y: center.dy,
          type: SnapPointType.center,
          axis: SnapAxis.both,
          sourceId: shape.id,
          sourceName: shape.name,
        ),
      );
    }

    return points;
  }

  /// Generate snap points from a frame (includes edge lines)
  static List<SnapPoint> fromFrame(FrameShape frame) {
    // Start with standard shape points
    final points = fromShape(frame, includeCenter: true);

    // Frames get additional edge-line snap points for alignment
    // These are continuous along the edges
    final bounds = frame.bounds;

    // Frame edges as snap targets (using frame coordinates)
    // Top edge
    points.add(
      SnapPoint(
        x: bounds.left + bounds.width / 2,
        y: bounds.top,
        type: SnapPointType.frameEdge,
        axis: SnapAxis.vertical, // Snaps Y coordinate
        sourceId: frame.id,
        sourceName: '${frame.name} top',
      ),
    );

    // Bottom edge
    points.add(
      SnapPoint(
        x: bounds.left + bounds.width / 2,
        y: bounds.bottom,
        type: SnapPointType.frameEdge,
        axis: SnapAxis.vertical,
        sourceId: frame.id,
        sourceName: '${frame.name} bottom',
      ),
    );

    // Left edge
    points.add(
      SnapPoint(
        x: bounds.left,
        y: bounds.top + bounds.height / 2,
        type: SnapPointType.frameEdge,
        axis: SnapAxis.horizontal, // Snaps X coordinate
        sourceId: frame.id,
        sourceName: '${frame.name} left',
      ),
    );

    // Right edge
    points.add(
      SnapPoint(
        x: bounds.right,
        y: bounds.top + bounds.height / 2,
        type: SnapPointType.frameEdge,
        axis: SnapAxis.horizontal,
        sourceId: frame.id,
        sourceName: '${frame.name} right',
      ),
    );

    return points;
  }

  /// Generate snap points from a selection rect
  static List<SnapPoint> fromRect(Rect rect, {String? label}) {
    final points = <SnapPoint>[];

    // Corners
    points.addAll([
      SnapPoint(
        x: rect.left,
        y: rect.top,
        type: SnapPointType.corner,
        axis: SnapAxis.both,
        sourceName: label,
      ),
      SnapPoint(
        x: rect.right,
        y: rect.top,
        type: SnapPointType.corner,
        axis: SnapAxis.both,
        sourceName: label,
      ),
      SnapPoint(
        x: rect.left,
        y: rect.bottom,
        type: SnapPointType.corner,
        axis: SnapAxis.both,
        sourceName: label,
      ),
      SnapPoint(
        x: rect.right,
        y: rect.bottom,
        type: SnapPointType.corner,
        axis: SnapAxis.both,
        sourceName: label,
      ),
    ]);

    // Edge midpoints
    points.addAll([
      SnapPoint(
        x: rect.center.dx,
        y: rect.top,
        type: SnapPointType.edgeMidpoint,
        axis: SnapAxis.horizontal,
        sourceName: label,
      ),
      SnapPoint(
        x: rect.center.dx,
        y: rect.bottom,
        type: SnapPointType.edgeMidpoint,
        axis: SnapAxis.horizontal,
        sourceName: label,
      ),
      SnapPoint(
        x: rect.left,
        y: rect.center.dy,
        type: SnapPointType.edgeMidpoint,
        axis: SnapAxis.vertical,
        sourceName: label,
      ),
      SnapPoint(
        x: rect.right,
        y: rect.center.dy,
        type: SnapPointType.edgeMidpoint,
        axis: SnapAxis.vertical,
        sourceName: label,
      ),
    ]);

    // Center
    points.add(
      SnapPoint(
        x: rect.center.dx,
        y: rect.center.dy,
        type: SnapPointType.center,
        axis: SnapAxis.both,
        sourceName: label,
      ),
    );

    return points;
  }
}

/// Index for efficient snap point queries
class SnapIndex {
  SnapIndex() : _xPoints = [], _yPoints = [];

  final List<_IndexedSnapPoint> _xPoints;
  final List<_IndexedSnapPoint> _yPoints;

  /// Add snap points to the index
  void addPoints(List<SnapPoint> points) {
    for (final point in points) {
      if (point.axis == SnapAxis.horizontal || point.axis == SnapAxis.both) {
        _xPoints.add(_IndexedSnapPoint(point.x, point));
      }
      if (point.axis == SnapAxis.vertical || point.axis == SnapAxis.both) {
        _yPoints.add(_IndexedSnapPoint(point.y, point));
      }
    }
  }

  /// Build index (sort for binary search)
  void build() {
    _xPoints.sort((a, b) => a.coordinate.compareTo(b.coordinate));
    _yPoints.sort((a, b) => a.coordinate.compareTo(b.coordinate));
  }

  /// Query snap points near a coordinate on X axis
  List<SnapPoint> queryX(double x, double threshold) {
    return _queryAxis(_xPoints, x, threshold);
  }

  /// Query snap points near a coordinate on Y axis
  List<SnapPoint> queryY(double y, double threshold) {
    return _queryAxis(_yPoints, y, threshold);
  }

  List<SnapPoint> _queryAxis(
    List<_IndexedSnapPoint> points,
    double coordinate,
    double threshold,
  ) {
    if (points.isEmpty) return [];

    final results = <SnapPoint>[];
    final minVal = coordinate - threshold;
    final maxVal = coordinate + threshold;

    // Binary search for start position
    var start = _lowerBound(points, minVal);

    // Collect all points within range
    while (start < points.length && points[start].coordinate <= maxVal) {
      results.add(points[start].point);
      start++;
    }

    return results;
  }

  int _lowerBound(List<_IndexedSnapPoint> points, double value) {
    var low = 0;
    var high = points.length;

    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (points[mid].coordinate < value) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  /// Clear all points
  void clear() {
    _xPoints.clear();
    _yPoints.clear();
  }

  /// Number of X-axis snap points
  int get xCount => _xPoints.length;

  /// Number of Y-axis snap points
  int get yCount => _yPoints.length;
}

class _IndexedSnapPoint {
  const _IndexedSnapPoint(this.coordinate, this.point);

  final double coordinate;
  final SnapPoint point;
}

/// Snap detector that finds snaps for moving shapes
class SnapDetector {
  SnapDetector({
    required this.config,
    required this.index,
  });

  final SnapConfig config;
  final SnapIndex index;

  /// Detect snaps for a selection rect being moved
  SnapResult detectSnap({
    required Rect selectionRect,
    required double zoom,
    Set<String> excludeIds = const {},
  }) {
    if (!config.enabled) return SnapResult.empty;

    final threshold = config.getEffectiveThreshold(zoom);

    // Generate snap points from selection rect
    final selectionPoints = SnapPointGenerator.fromRect(selectionRect);

    SnapPoint? bestSnapX;
    SnapPoint? bestSnapY;
    double bestDeltaX = double.infinity;
    double bestDeltaY = double.infinity;
    SnapPoint? matchedSelPointX;
    SnapPoint? matchedSelPointY;

    // Check each selection point against index
    for (final selPoint in selectionPoints) {
      // Check X axis snapping
      if (selPoint.axis == SnapAxis.horizontal ||
          selPoint.axis == SnapAxis.both) {
        final nearbyX = index.queryX(selPoint.x, threshold);
        for (final target in nearbyX) {
          if (excludeIds.contains(target.sourceId)) continue;

          final delta = target.x - selPoint.x;
          if (delta.abs() < bestDeltaX.abs()) {
            bestDeltaX = delta;
            bestSnapX = target;
            matchedSelPointX = selPoint;
          }
        }
      }

      // Check Y axis snapping
      if (selPoint.axis == SnapAxis.vertical || selPoint.axis == SnapAxis.both) {
        final nearbyY = index.queryY(selPoint.y, threshold);
        for (final target in nearbyY) {
          if (excludeIds.contains(target.sourceId)) continue;

          final delta = target.y - selPoint.y;
          if (delta.abs() < bestDeltaY.abs()) {
            bestDeltaY = delta;
            bestSnapY = target;
            matchedSelPointY = selPoint;
          }
        }
      }
    }

    // Build snap lines
    final snapLines = <SnapLine>[];
    final snapPoints = <SnapPoint>[];

    if (bestSnapX != null && matchedSelPointX != null) {
      snapPoints.add(bestSnapX);

      // Vertical line showing X alignment
      final minY = math.min(
        matchedSelPointX.y + (bestDeltaY.isFinite ? bestDeltaY : 0),
        bestSnapX.y,
      );
      final maxY = math.max(
        matchedSelPointX.y + (bestDeltaY.isFinite ? bestDeltaY : 0),
        bestSnapX.y,
      );

      snapLines.add(
        SnapLine(
          start: Offset(bestSnapX.x, minY - 20),
          end: Offset(bestSnapX.x, maxY + 20),
          axis: SnapAxis.horizontal,
          isCenter: bestSnapX.type == SnapPointType.center,
        ),
      );
    } else {
      bestDeltaX = 0;
    }

    if (bestSnapY != null && matchedSelPointY != null) {
      snapPoints.add(bestSnapY);

      // Horizontal line showing Y alignment
      final minX = math.min(
        matchedSelPointY.x + (bestDeltaX.isFinite ? bestDeltaX : 0),
        bestSnapY.x,
      );
      final maxX = math.max(
        matchedSelPointY.x + (bestDeltaX.isFinite ? bestDeltaX : 0),
        bestSnapY.x,
      );

      snapLines.add(
        SnapLine(
          start: Offset(minX - 20, bestSnapY.y),
          end: Offset(maxX + 20, bestSnapY.y),
          axis: SnapAxis.vertical,
          isCenter: bestSnapY.type == SnapPointType.center,
        ),
      );
    } else {
      bestDeltaY = 0;
    }

    return SnapResult(
      snapX: bestSnapX,
      snapY: bestSnapY,
      deltaX: bestDeltaX,
      deltaY: bestDeltaY,
      snapPoints: snapPoints,
      snapLines: snapLines,
    );
  }
}
