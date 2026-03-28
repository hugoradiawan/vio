import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'handle_types.dart';
import 'selection_handle_metrics.dart';

enum SelectionEdge {
  top,
  right,
  bottom,
  left,
}

extension SelectionEdgeX on SelectionEdge {
  HandlePosition get asEdgeHandle {
    switch (this) {
      case SelectionEdge.top:
        return HandlePosition.topCenter;
      case SelectionEdge.right:
        return HandlePosition.middleRight;
      case SelectionEdge.bottom:
        return HandlePosition.bottomCenter;
      case SelectionEdge.left:
        return HandlePosition.middleLeft;
    }
  }
}

class SelectionHitResult {
  const SelectionHitResult.handle(this.handle) : edge = null;

  const SelectionHitResult.edge(this.edge) : handle = null;

  final HandlePosition? handle;
  final SelectionEdge? edge;

  bool get isHandle => handle != null;

  HandlePosition get effectiveHandle => handle ?? edge!.asEdgeHandle;
}

class SelectionHitTestConfig {
  const SelectionHitTestConfig({
    this.handleSize = SelectionHandleMetrics.resizeVisualSize,
    this.handleHitSize = SelectionHandleMetrics.resizeHitSize,
    this.rotationHandleOffset = SelectionHandleMetrics.rotationOffset,
    this.rotationHitRadius = SelectionHandleMetrics.rotationHitRadius,
    this.edgeHitSlop = SelectionHandleMetrics.edgeHitSlop,
    this.cornerHitSlop = SelectionHandleMetrics.cornerHitSlop,
    this.includeEdges = true,
    this.includeRotation = true,
  });

  final double handleSize;
  final double handleHitSize;
  final double rotationHandleOffset;
  final double rotationHitRadius;
  final double edgeHitSlop;
  final double cornerHitSlop;
  final bool includeEdges;
  final bool includeRotation;
}

SelectionHitResult? hitTestSelectionAffordance({
  required Offset screenPoint,
  required Rect selectionBounds,
  required double zoom,
  required Offset viewportOffset,
  required bool isSingleTextSelection,
  double selectionRotationDegrees = 0,
  SelectionHitTestConfig config = const SelectionHitTestConfig(),
}) {
  Offset toScreen(Offset canvasPoint) {
    return Offset(
      canvasPoint.dx * zoom + viewportOffset.dx,
      canvasPoint.dy * zoom + viewportOffset.dy,
    );
  }

  // When the selection is rotated, un-rotate the screen point around the
  // screen-space selection center so all axis-aligned logic still works.
  Offset effectiveScreenPoint = screenPoint;
  if (selectionRotationDegrees.abs() > 0.01) {
    final screenCenter = toScreen(selectionBounds.center);
    final radians = -selectionRotationDegrees * math.pi / 180.0;
    final cosA = math.cos(radians);
    final sinA = math.sin(radians);
    final dx = screenPoint.dx - screenCenter.dx;
    final dy = screenPoint.dy - screenCenter.dy;
    effectiveScreenPoint = Offset(
      screenCenter.dx + dx * cosA - dy * sinA,
      screenCenter.dy + dx * sinA + dy * cosA,
    );
  }

  final centerX = selectionBounds.center.dx;
  final centerY = selectionBounds.center.dy;
  final rotationOffsetInCanvas = SelectionHandleMetrics.toCanvasUnits(
    screenPx: config.rotationHandleOffset,
    zoom: zoom,
  );

  final handlePositions = <HandlePosition, Offset>{
    HandlePosition.topLeft: Offset(selectionBounds.left, selectionBounds.top),
    HandlePosition.topCenter: Offset(centerX, selectionBounds.top),
    HandlePosition.topRight: Offset(selectionBounds.right, selectionBounds.top),
    HandlePosition.middleLeft: Offset(selectionBounds.left, centerY),
    HandlePosition.middleRight: Offset(selectionBounds.right, centerY),
    HandlePosition.bottomLeft:
        Offset(selectionBounds.left, selectionBounds.bottom),
    HandlePosition.bottomCenter: Offset(centerX, selectionBounds.bottom),
    HandlePosition.bottomRight:
        Offset(selectionBounds.right, selectionBounds.bottom),
    HandlePosition.rotation:
        Offset(centerX, selectionBounds.top - rotationOffsetInCanvas),
  };

  bool isTextHandle(HandlePosition position) {
    return position == HandlePosition.rotation ||
        position == HandlePosition.topLeft ||
        position == HandlePosition.topRight ||
        position == HandlePosition.bottomLeft ||
        position == HandlePosition.bottomRight;
  }

  for (final entry in handlePositions.entries) {
    final position = entry.key;
    if (!config.includeRotation && position == HandlePosition.rotation) {
      continue;
    }
    if (isSingleTextSelection && !isTextHandle(position)) {
      continue;
    }

    final center = toScreen(entry.value);
    final rect = Rect.fromCenter(
      center: center,
      width: config.handleHitSize,
      height: config.handleHitSize,
    );

    if (position == HandlePosition.rotation) {
      if ((effectiveScreenPoint - center).distance <=
          config.rotationHitRadius) {
        return SelectionHitResult.handle(position);
      }
      continue;
    }

    if (rect.contains(effectiveScreenPoint)) {
      return SelectionHitResult.handle(position);
    }
  }

  if (!config.includeEdges || isSingleTextSelection) {
    return null;
  }

  final topLeft = toScreen(Offset(selectionBounds.left, selectionBounds.top));
  final topRight = toScreen(Offset(selectionBounds.right, selectionBounds.top));
  final bottomLeft =
      toScreen(Offset(selectionBounds.left, selectionBounds.bottom));
  bool inX(double x, double minX, double maxX) => x >= minX && x <= maxX;
  bool inY(double y, double minY, double maxY) => y >= minY && y <= maxY;

  final slop = config.edgeHitSlop;
  final cornerSlop = config.cornerHitSlop;
  final minX = topLeft.dx < topRight.dx ? topLeft.dx : topRight.dx;
  final maxX = topLeft.dx > topRight.dx ? topLeft.dx : topRight.dx;
  final minY = topLeft.dy < bottomLeft.dy ? topLeft.dy : bottomLeft.dy;
  final maxY = topLeft.dy > bottomLeft.dy ? topLeft.dy : bottomLeft.dy;

  // Figma-like: when hovering near selection border corners, use diagonal
  // resize cursors even if not exactly over the square handle.
  bool near(Offset point, Offset target, double radius) {
    return (point - target).distance <= radius;
  }

  if (near(effectiveScreenPoint, topLeft, cornerSlop)) {
    return const SelectionHitResult.handle(HandlePosition.topLeft);
  }

  if (near(effectiveScreenPoint, topRight, cornerSlop)) {
    return const SelectionHitResult.handle(HandlePosition.topRight);
  }

  if (near(effectiveScreenPoint, bottomLeft, cornerSlop)) {
    return const SelectionHitResult.handle(HandlePosition.bottomLeft);
  }

  final bottomRight =
      toScreen(Offset(selectionBounds.right, selectionBounds.bottom));
  if (near(effectiveScreenPoint, bottomRight, cornerSlop)) {
    return const SelectionHitResult.handle(HandlePosition.bottomRight);
  }

  if ((effectiveScreenPoint.dy - topLeft.dy).abs() <= slop &&
      inX(effectiveScreenPoint.dx, minX, maxX)) {
    return const SelectionHitResult.edge(SelectionEdge.top);
  }

  if ((effectiveScreenPoint.dy - bottomLeft.dy).abs() <= slop &&
      inX(effectiveScreenPoint.dx, minX, maxX)) {
    return const SelectionHitResult.edge(SelectionEdge.bottom);
  }

  if ((effectiveScreenPoint.dx - topLeft.dx).abs() <= slop &&
      inY(effectiveScreenPoint.dy, minY, maxY)) {
    return const SelectionHitResult.edge(SelectionEdge.left);
  }

  if ((effectiveScreenPoint.dx - topRight.dx).abs() <= slop &&
      inY(effectiveScreenPoint.dy, minY, maxY)) {
    return const SelectionHitResult.edge(SelectionEdge.right);
  }

  return null;
}
