import 'dart:async';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:vio_core/vio_core.dart';

import '../../../core/core.dart';
import '../models/handle_types.dart';
import '../models/selection_handle_metrics.dart';
import '../models/selection_hit_test.dart';

part 'canvas_bloc_commands.dart';
part 'canvas_bloc_hierarchy.dart';
part 'canvas_bloc_history.dart';
part 'canvas_bloc_interaction.dart';
part 'canvas_bloc_rust.dart';
part 'canvas_bloc_sync.dart';
part 'canvas_bloc_text.dart';
part 'canvas_bloc_viewport.dart';
part 'canvas_event.dart';
part 'canvas_state.dart';

/// UUID generator for new shapes
const _uuid = Uuid();

/// Helper class for corner radius hit test result
class _CornerRadiusHit {
  const _CornerRadiusHit({required this.index, required this.position});
  final int index;
  final Offset position;
}

class _PruneEmptyGroupsResult {
  const _PruneEmptyGroupsResult({
    required this.shapes,
    required this.deletedGroupIds,
  });

  final Map<String, Shape> shapes;
  final Set<String> deletedGroupIds;
}

/// Maximum number of undo states to keep
const _maxUndoHistory = 50;

/// Manages the infinite canvas state including:
/// - Viewport (pan/zoom transforms)
/// - Shapes on canvas
/// - Selection state
/// - Interaction mode
/// - Manual undo/redo stack for shape changes
/// - Server sync for persistence
class CanvasBloc extends Bloc<CanvasEvent, CanvasState>
    with
        _CanvasHistoryMixin,
        _CanvasHierarchyMixin,
        _CanvasInteractionMixin,
        _CanvasCommandsMixin,
        _CanvasViewportMixin,
        _CanvasTextMixin,
        _CanvasSyncMixin,
        _CanvasRustMixin {
  CanvasBloc({GrpcCanvasRepository? repository})
      : _repository = repository,
        super(CanvasState()) {
    // Initialize undo stack with initial shapes (empty)
    _undoStack.add(Map.from(state.shapes));

    on<CanvasInitialized>(_onInitialized);
    on<ViewportPanned>(_onViewportPanned);
    on<ViewportZoomed>(_onViewportZoomed);
    on<ViewportReset>(_onViewportReset);
    on<ZoomIn>(_onZoomIn);
    on<ZoomOut>(_onZoomOut);
    on<ZoomSet>(_onZoomSet);
    on<SelectionCentered>(_onSelectionCentered);
    on<PointerDown>(_onPointerDown);
    on<PointerMove>(_onPointerMove);
    on<PointerUp>(_onPointerUp);
    on<CanvasDoubleClicked>(_onCanvasDoubleClicked);
    on<CanvasPointerExited>(_onCanvasPointerExited);
    on<SelectionCleared>(_onSelectionCleared);
    on<ShapeAdded>(_onShapeAdded);
    on<ShapesAdded>(_onShapesAdded);
    on<ShapesReplaced>(_onShapesReplaced);
    on<ShapeRemoved>(_onShapeRemoved);
    on<ShapesRemoved>(_onShapesRemoved);
    on<ShapeUpdated>(_onShapeUpdated);
    on<ShapeSelected>(_onShapeSelected);
    on<ShapesSelected>(_onShapesSelected);
    // Layer panel events
    on<LayerExpanded>(_onLayerExpanded);
    on<LayerCollapsed>(_onLayerCollapsed);
    on<LayerHovered>(_onLayerHovered);
    on<ShapeVisibilityToggled>(_onShapeVisibilityToggled);
    on<ShapeLockToggled>(_onShapeLockToggled);
    on<ShapeRenamed>(_onShapeRenamed);
    // Clipboard events
    on<CopySelected>(_onCopySelected);
    on<CutSelected>(_onCutSelected);
    on<PasteShapes>(_onPasteShapes);
    on<DuplicateSelected>(_onDuplicateSelected);
    on<DeleteSelected>(_onDeleteSelected);
    // Undo/redo events
    on<Undo>(_onUndo);
    on<Redo>(_onRedo);
    // Sync events
    on<CanvasLoadRequested>(_onCanvasLoadRequested);
    on<CanvasLoadSucceeded>(_onCanvasLoadSucceeded);
    on<CanvasLoadFailed>(_onCanvasLoadFailed);
    on<CanvasSyncRequested>(_onCanvasSyncRequested);
    on<CanvasSyncSucceeded>(_onCanvasSyncSucceeded);
    on<CanvasSyncFailed>(_onCanvasSyncFailed);

    // Layer tree drag/drop reparent
    on<ShapesReparented>(_onShapesReparented);

    // Grouping
    on<CreateGroupFromSelection>(_onCreateGroupFromSelection);
    on<UngroupSelected>(_onUngroupSelected);

    // Z-order
    on<BringToFrontSelected>(_onBringToFrontSelected);
    on<SendToBackSelected>(_onSendToBackSelected);

    // Text editing events
    on<TextEditRequested>(_onTextEditRequested);
    on<TextEditCommitted>(_onTextEditCommitted);
    on<TextEditLayoutChanged>(_onTextEditLayoutChanged);
    on<TextEditCanceled>(_onTextEditCanceled);
  }

  /// Repository for server communication (optional for offline mode)
  @override
  final GrpcCanvasRepository? _repository;

  /// Manual undo stack - stores snapshots of shapes map
  @override
  final List<Map<String, Shape>> _undoStack = [];

  /// Manual redo stack - stores snapshots for redo
  @override
  final List<Map<String, Shape>> _redoStack = [];

  // ============================================================================
  // Web perf: snap/hover throttling & snap index caching
  // ============================================================================

  static const Duration _snapThrottle = Duration(milliseconds: 16); // ~60fps
  static const Duration _hoverThrottle = Duration(milliseconds: 16); // ~60fps

  SnapDetector? _activeSnapDetector;
  Set<String> _activeSnapExcludeIds = const {};
  DateTime _lastSnapComputeAt = DateTime.fromMillisecondsSinceEpoch(0);
  Offset _lastSnapDragOffset = Offset.zero;
  SnapResult _lastSnapResult = SnapResult.empty;

  DateTime _lastHoverComputeAt = DateTime.fromMillisecondsSinceEpoch(0);
  Offset? _lastHoverScreenPoint;

  @override
  void _beginSnapSession(Set<String> selectedIds) {
    // Build once per drag session; selected shapes are excluded.
    final snapIndex = SnapIndex();
    for (final shape in state.shapes.values) {
      if (selectedIds.contains(shape.id)) continue;

      if (shape is FrameShape) {
        snapIndex.addPoints(SnapPointGenerator.fromFrame(shape));
      } else {
        snapIndex.addPoints(SnapPointGenerator.fromShape(shape));
      }
    }
    snapIndex.build();

    _activeSnapDetector =
        SnapDetector(config: const SnapConfig(), index: snapIndex);
    _activeSnapExcludeIds = selectedIds;
    _lastSnapComputeAt = DateTime.fromMillisecondsSinceEpoch(0);
    _lastSnapDragOffset = Offset.zero;
    _lastSnapResult = SnapResult.empty;
  }

  @override
  void _endSnapSession() {
    _activeSnapDetector = null;
    _activeSnapExcludeIds = const {};
    _lastSnapComputeAt = DateTime.fromMillisecondsSinceEpoch(0);
    _lastSnapDragOffset = Offset.zero;
    _lastSnapResult = SnapResult.empty;
  }

  @override
  bool _shouldRecomputeHover(Offset screenPoint) {
    final now = DateTime.now();
    final lastPoint = _lastHoverScreenPoint;
    final movedEnough =
        lastPoint == null || (screenPoint - lastPoint).distance >= 1.0;

    if (!movedEnough && now.difference(_lastHoverComputeAt) < _hoverThrottle) {
      return false;
    }

    _lastHoverComputeAt = now;
    _lastHoverScreenPoint = screenPoint;
    return true;
  }

  /// Push current shapes to undo stack (call after shape-changing operations)
  @override
  void _pushUndoState(Map<String, Shape> shapes) {
    // Clear redo stack when new action is performed
    _redoStack.clear();

    // Add to undo stack
    _undoStack.add(Map.from(shapes));

    // Limit stack size
    while (_undoStack.length > _maxUndoHistory) {
      _undoStack.removeAt(0);
    }

    VioLogger.debug('Pushed undo state. Stack size: ${_undoStack.length}');
  }

  /// Track a shape operation for syncing to repository
  @override
  void _notifyRepositoryShapeAdded(Shape shape) {
    _repository?.addShape(shape);
  }

  @override
  void _notifyRepositoryShapeUpdated(Shape shape) {
    _repository?.updateShape(shape);
  }

  @override
  void _notifyRepositoryShapeDeleted(String shapeId) {
    _repository?.deleteShape(shapeId);
  }

  /// Expand all ancestors (frameId / parentId chain) for the given shapes,
  /// using [shapes] rather than [state.shapes].
  @override
  Set<String> _expandAncestorsForShapesIn(
    Map<String, Shape> shapes,
    List<String> shapeIds,
    Set<String> currentExpanded,
  ) {
    final expanded = Set<String>.from(currentExpanded);

    for (final shapeId in shapeIds) {
      final shape = shapes[shapeId];
      if (shape == null) continue;

      String? parentId = shape.parentId ?? shape.frameId;
      while (parentId != null) {
        final parent = shapes[parentId];
        if (parent == null) break;
        expanded.add(parentId);
        parentId = parent.parentId ?? parent.frameId;
      }
    }

    return expanded;
  }

  @override
  String? _effectiveContainerIdFor({
    required Map<String, Shape> shapes,
    required String? parentId,
    required String? frameId,
  }) {
    final parent = parentId == null ? null : shapes[parentId];
    if (parentId != null && parent is GroupShape) {
      return parentId;
    }
    final frame = frameId == null ? null : shapes[frameId];
    if (frameId != null && frame is FrameShape) {
      return frameId;
    }
    return null;
  }

  @override
  int _nextSortOrderForNewShape({
    required Map<String, Shape> shapes,
    required String? parentId,
    required String? frameId,
  }) {
    final containerId = _effectiveContainerIdFor(
      shapes: shapes,
      parentId: parentId,
      frameId: frameId,
    );

    var maxOrder = -1;
    for (final shape in shapes.values) {
      final shapeContainer = _effectiveContainerIdFor(
        shapes: shapes,
        parentId: shape.parentId,
        frameId: shape.frameId,
      );
      if (shapeContainer == containerId) {
        if (shape.sortOrder > maxOrder) {
          maxOrder = shape.sortOrder;
        }
      }
    }

    return maxOrder + 1;
  }

  @override
  Map<String, Shape> _reorderSelectionInSiblings({
    required Map<String, Shape> shapes,
    required List<String> selectedIds,
    required bool toFront,
  }) {
    if (selectedIds.isEmpty) return shapes;

    final shapesById = shapes;

    // Group selected IDs by their effective container (sibling scope).
    final selectedByScope = <String?, List<String>>{};
    for (final id in selectedIds) {
      final shape = shapesById[id];
      if (shape == null) continue;
      if (shape.blocked) continue;
      final scope = _effectiveContainerIdFor(
        shapes: shapesById,
        parentId: shape.parentId,
        frameId: shape.frameId,
      );
      selectedByScope.putIfAbsent(scope, () => []).add(id);
    }

    if (selectedByScope.isEmpty) return shapes;

    final nextShapes = Map<String, Shape>.from(shapesById);

    int compareZ(Shape a, Shape b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      if (byOrder != 0) return byOrder;
      return a.id.compareTo(b.id);
    }

    for (final entry in selectedByScope.entries) {
      final scope = entry.key;
      final scopeSelected = entry.value.toSet();

      final scopeSiblings = <Shape>[];
      for (final shape in shapesById.values) {
        final shapeScope = _effectiveContainerIdFor(
          shapes: shapesById,
          parentId: shape.parentId,
          frameId: shape.frameId,
        );
        if (shapeScope == scope) {
          scopeSiblings.add(shape);
        }
      }

      if (scopeSiblings.isEmpty) continue;

      scopeSiblings.sort(compareZ);
      final moved = <Shape>[];
      final remaining = <Shape>[];
      for (final shape in scopeSiblings) {
        if (scopeSelected.contains(shape.id)) {
          moved.add(shape);
        } else {
          remaining.add(shape);
        }
      }

      final reordered =
          toFront ? [...remaining, ...moved] : [...moved, ...remaining];

      for (var i = 0; i < reordered.length; i++) {
        final shape = reordered[i];
        if (shape.sortOrder != i) {
          nextShapes[shape.id] = shape.copyWith(sortOrder: i);
        }
      }
    }

    return nextShapes;
  }

  /// Detect snap points for current drag operation
  @override
  SnapResult _detectSnap(Offset dragOffset) {
    final selectionRect = _getSelectionRectWithOffset(dragOffset);
    if (selectionRect == null) return SnapResult.empty;

    final detector = _activeSnapDetector;
    if (detector == null) {
      // Fallback: should be rare (e.g., programmatic move without pointerDown).
      _beginSnapSession(state.selectedShapeIds.toSet());
    }

    final now = DateTime.now();
    final shouldThrottle = now.difference(_lastSnapComputeAt) < _snapThrottle &&
        (dragOffset - _lastSnapDragOffset).distance < 0.5;
    if (shouldThrottle) {
      return _lastSnapResult;
    }

    final computed = _activeSnapDetector!.detectSnap(
      selectionRect: selectionRect,
      zoom: state.zoom,
      excludeIds: _activeSnapExcludeIds,
    );

    _lastSnapComputeAt = now;
    _lastSnapDragOffset = dragOffset;
    _lastSnapResult = computed;
    return computed;
  }

  /// Get combined selection rect with drag offset applied
  Rect? _getSelectionRectWithOffset(Offset offset) {
    if (state.selectedShapeIds.isEmpty) return null;

    double? minX, minY, maxX, maxY;

    for (final shapeId in state.selectedShapeIds) {
      final shape = state.shapes[shapeId];
      if (shape == null) continue;

      final bounds = shape.bounds;
      final corners = [
        shape.transformPoint(Offset(bounds.left, bounds.top)),
        shape.transformPoint(Offset(bounds.right, bounds.top)),
        shape.transformPoint(Offset(bounds.right, bounds.bottom)),
        shape.transformPoint(Offset(bounds.left, bounds.bottom)),
      ];

      for (final corner in corners) {
        final x = corner.dx + offset.dx;
        final y = corner.dy + offset.dy;
        minX = minX == null ? x : (x < minX ? x : minX);
        minY = minY == null ? y : (y < minY ? y : minY);
        maxX = maxX == null ? x : (x > maxX ? x : maxX);
        maxY = maxY == null ? y : (y > maxY ? y : maxY);
      }
    }

    if (minX == null || minY == null || maxX == null || maxY == null) {
      return null;
    }

    return Rect.fromLTWH(minX, minY, maxX - minX, maxY - minY);
  }

  @override
  Future<void> close() {
    _syncStatusSubscription?.cancel();
    return super.close();
  }

  // --------------------------------------------------------------------------
  // Rust engine sync: detects shape changes on every state emission
  // --------------------------------------------------------------------------

  @override
  void onChange(Change<CanvasState> change) {
    super.onChange(change);

    // Only sync to Rust when the shapes map object has changed.
    if (!identical(change.nextState.shapes, change.currentState.shapes)) {
      _syncShapesToRust(change.nextState.shapes);
    }
  }
}
