import 'dart:async';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:vio_core/vio_core.dart';

import '../../../core/core.dart';
import '../models/handle_types.dart';

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
class CanvasBloc extends Bloc<CanvasEvent, CanvasState> {
  CanvasBloc({GrpcCanvasRepository? repository})
      : _repository = repository,
        super(CanvasState(shapes: _createTestShapes())) {
    // Initialize undo stack with initial shapes
    _undoStack.add(Map.from(state.shapes));

    on<CanvasInitialized>(_onInitialized);
    on<ViewportPanned>(_onViewportPanned);
    on<ViewportZoomed>(_onViewportZoomed);
    on<ViewportReset>(_onViewportReset);
    on<ZoomIn>(_onZoomIn);
    on<ZoomOut>(_onZoomOut);
    on<ZoomSet>(_onZoomSet);
    on<PointerDown>(_onPointerDown);
    on<PointerMove>(_onPointerMove);
    on<PointerUp>(_onPointerUp);
    on<CanvasPointerExited>(_onCanvasPointerExited);
    on<SelectionCleared>(_onSelectionCleared);
    on<ShapeAdded>(_onShapeAdded);
    on<ShapesAdded>(_onShapesAdded);
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

  void _onTextEditRequested(
    TextEditRequested event,
    Emitter<CanvasState> emit,
  ) {
    final shape = state.shapes[event.shapeId];
    if (shape is! TextShape) {
      return;
    }

    final selection = [event.shapeId];
    emit(
      state.copyWith(
        selectedShapeIds: selection,
        expandedLayerIds: _expandAncestorsForShapes(selection),
        editingTextShapeId: event.shapeId,
        interactionMode: InteractionMode.idle,
        clearDragStart: true,
        clearCurrentPointer: true,
        clearDragOffset: true,
        clearSnap: true,
      ),
    );
  }

  void _onTextEditLayoutChanged(
    TextEditLayoutChanged event,
    Emitter<CanvasState> emit,
  ) {
    // Only apply while the shape is actively being edited.
    if (state.editingTextShapeId != event.shapeId) {
      return;
    }

    final existing = state.shapes[event.shapeId];
    if (existing is! TextShape) {
      return;
    }

    // Grow-only during editing to avoid jitter when deleting text.
    final nextWidth = math.max(existing.textWidth, event.width);
    final nextHeight = math.max(existing.textHeight, event.height);

    if (nextWidth == existing.textWidth && nextHeight == existing.textHeight) {
      return;
    }

    final updated = existing.copyWith(
      textWidth: nextWidth,
      textHeight: nextHeight,
    );

    final newShapes = Map<String, Shape>.from(state.shapes)
      ..[event.shapeId] = updated;

    emit(state.copyWith(shapes: newShapes));
  }

  /// Repository for server communication (optional for offline mode)
  final GrpcCanvasRepository? _repository;

  /// Manual undo stack - stores snapshots of shapes map
  final List<Map<String, Shape>> _undoStack = [];

  /// Manual redo stack - stores snapshots for redo
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

  void _endSnapSession() {
    _activeSnapDetector = null;
    _activeSnapExcludeIds = const {};
    _lastSnapComputeAt = DateTime.fromMillisecondsSinceEpoch(0);
    _lastSnapDragOffset = Offset.zero;
    _lastSnapResult = SnapResult.empty;
  }

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

  /// Whether undo is available
  bool get canUndo => _undoStack.length > 1;

  /// Whether redo is available
  bool get canRedo => _redoStack.isNotEmpty;

  /// Push current shapes to undo stack (call after shape-changing operations)
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

  /// Handle undo event
  void _onUndo(Undo event, Emitter<CanvasState> emit) {
    if (!canUndo) {
      VioLogger.debug('Undo called but canUndo is false');
      return;
    }

    // Current state goes to redo stack
    _redoStack.add(_undoStack.removeLast());

    // Restore previous state
    final previousShapes = _undoStack.last;

    VioLogger.debug(
      'Undo: restored state. Undo stack: ${_undoStack.length}, Redo stack: ${_redoStack.length}',
    );

    emit(
      state.copyWith(
        shapes: Map.from(previousShapes),
        interactionMode: InteractionMode.idle,
        clearDragStart: true,
        clearDragOffset: true,
        clearSnap: true,
      ),
    );
  }

  /// Handle redo event
  void _onRedo(Redo event, Emitter<CanvasState> emit) {
    if (!canRedo) {
      VioLogger.debug('Redo called but canRedo is false');
      return;
    }

    // Move from redo to undo stack
    final nextShapes = _redoStack.removeLast();
    _undoStack.add(nextShapes);

    VioLogger.debug(
      'Redo: restored state. Undo stack: ${_undoStack.length}, Redo stack: ${_redoStack.length}',
    );

    emit(
      state.copyWith(
        shapes: Map.from(nextShapes),
        interactionMode: InteractionMode.idle,
        clearDragStart: true,
        clearDragOffset: true,
        clearSnap: true,
      ),
    );
  }

  /// Create test shapes for development
  static Map<String, Shape> _createTestShapes() {
    final shapes = <String, Shape>{};

    // Frame (artboard)
    const frame = FrameShape(
      id: 'frame-1',
      name: 'Frame 1',
      x: 0,
      y: 0,
      frameWidth: 800,
      frameHeight: 600,
      fills: [ShapeFill(color: 0xFF2D2D2D)],
      strokes: [ShapeStroke(color: 0xFF404040)],
    );
    shapes[frame.id] = frame;

    // Blue rectangle
    final rect1 = RectangleShape(
      id: 'rect-1',
      name: 'Rectangle 1',
      x: 50,
      y: 50,
      rectWidth: 200,
      rectHeight: 150,
      sortOrder: 1,
      r1: 8,
      r2: 8,
      r3: 8,
      r4: 8,
      fills: const [ShapeFill(color: 0xFF3B82F6)],
      strokes: const [ShapeStroke(color: 0xFF1D4ED8, width: 2)],
      frameId: frame.id,
    );
    shapes[rect1.id] = rect1;

    // Green rectangle
    final rect2 = RectangleShape(
      id: 'rect-2',
      name: 'Rectangle 2',
      x: 300,
      y: 100,
      rectWidth: 180,
      rectHeight: 120,
      sortOrder: 2,
      fills: const [ShapeFill(color: 0xFF22C55E)],
      strokes: const [ShapeStroke(color: 0xFF16A34A, width: 2)],
      frameId: frame.id,
    );
    shapes[rect2.id] = rect2;

    // Red ellipse (center at 600,200 with semi-axes 80,60 means bounds: x=520, y=140, w=160, h=120)
    final ellipse1 = EllipseShape(
      id: 'ellipse-1',
      name: 'Ellipse 1',
      x: 520,
      y: 140,
      ellipseWidth: 160,
      ellipseHeight: 120,
      sortOrder: 3,
      fills: const [ShapeFill(color: 0xFFEF4444)],
      strokes: const [ShapeStroke(color: 0xFFDC2626, width: 2)],
      frameId: frame.id,
    );
    shapes[ellipse1.id] = ellipse1;

    // Yellow rectangle with no fill, just stroke
    final rect3 = RectangleShape(
      id: 'rect-3',
      name: 'Rectangle 3',
      x: 100,
      y: 300,
      rectWidth: 250,
      rectHeight: 180,
      sortOrder: 4,
      strokes: const [
        ShapeStroke(
          color: 0xFFFACC15,
          width: 3,
          alignment: StrokeAlignment.inside,
        ),
      ],
      frameId: frame.id,
    );
    shapes[rect3.id] = rect3;

    // Purple circle (center at 550,400 with radius 70 means bounds: x=480, y=330, w=140, h=140)
    final ellipse2 = EllipseShape(
      id: 'ellipse-2',
      name: 'Circle 1',
      x: 480,
      y: 330,
      ellipseWidth: 140,
      ellipseHeight: 140,
      sortOrder: 5,
      fills: const [ShapeFill(color: 0xFFA855F7)],
      strokes: const [ShapeStroke(color: 0xFF9333EA, width: 2)],
      frameId: frame.id,
    );
    shapes[ellipse2.id] = ellipse2;

    return shapes;
  }

  void _onInitialized(
    CanvasInitialized event,
    Emitter<CanvasState> emit,
  ) {
    emit(
      state.copyWith(
        viewportSize: Size(event.width, event.height),
      ),
    );
  }

  void _onViewportPanned(
    ViewportPanned event,
    Emitter<CanvasState> emit,
  ) {
    final newOffset = Offset(
      state.viewportOffset.dx + event.deltaX,
      state.viewportOffset.dy + event.deltaY,
    );
    emit(state.copyWith(viewportOffset: newOffset));
  }

  void _onViewportZoomed(
    ViewportZoomed event,
    Emitter<CanvasState> emit,
  ) {
    // Calculate new zoom level
    final newZoom = (state.zoom * event.scaleFactor).clamp(0.01, 64.0);

    // Zoom towards the focal point (mouse position in screen coordinates)
    // The point under the mouse should stay in the same position after zoom
    //
    // Before zoom: canvasPoint = (screenPoint - offset) / oldZoom
    // After zoom:  canvasPoint = (screenPoint - newOffset) / newZoom
    //
    // We want the same canvas point under the mouse, so:
    // (focalPoint - offset) / oldZoom = (focalPoint - newOffset) / newZoom
    //
    // Solving for newOffset:
    // newOffset = focalPoint - (focalPoint - offset) * (newZoom / oldZoom)

    final zoomRatio = newZoom / state.zoom;
    final newOffset = Offset(
      event.focalX - (event.focalX - state.viewportOffset.dx) * zoomRatio,
      event.focalY - (event.focalY - state.viewportOffset.dy) * zoomRatio,
    );

    emit(
      state.copyWith(
        zoom: newZoom,
        viewportOffset: newOffset,
      ),
    );
  }

  void _onViewportReset(
    ViewportReset event,
    Emitter<CanvasState> emit,
  ) {
    emit(
      state.copyWith(
        zoom: 1.0,
        viewportOffset: const Offset(0, 0),
      ),
    );
  }

  void _onZoomIn(
    ZoomIn event,
    Emitter<CanvasState> emit,
  ) {
    _zoomAtCenter(1.25, emit);
  }

  void _onZoomOut(
    ZoomOut event,
    Emitter<CanvasState> emit,
  ) {
    _zoomAtCenter(1 / 1.25, emit);
  }

  void _onZoomSet(
    ZoomSet event,
    Emitter<CanvasState> emit,
  ) {
    final targetZoom = event.zoom.clamp(0.01, 64.0);
    final scaleFactor = targetZoom / state.zoom;
    _zoomAtCenter(scaleFactor, emit);
  }

  void _zoomAtCenter(double scaleFactor, Emitter<CanvasState> emit) {
    // Use viewport center as focal point
    final centerX = state.viewportSize.width / 2;
    final centerY = state.viewportSize.height / 2;

    // Calculate new zoom level
    final newZoom = (state.zoom * scaleFactor).clamp(0.01, 64.0);

    // Adjust offset to zoom towards center
    final zoomDelta = newZoom / state.zoom;
    final newOffset = Offset(
      centerX - (centerX - state.viewportOffset.dx) * zoomDelta,
      centerY - (centerY - state.viewportOffset.dy) * zoomDelta,
    );

    emit(
      state.copyWith(
        zoom: newZoom,
        viewportOffset: newOffset,
      ),
    );
  }

  void _onPointerDown(
    PointerDown event,
    Emitter<CanvasState> emit,
  ) {
    final screenPoint = Offset(event.x, event.y);
    final canvasPoint = _screenToCanvas(screenPoint);

    // Text tool: click-to-create and start inline edit
    if (event.tool == CanvasPointerTool.drawText) {
      final newId = _uuid.v4();

      FrameShape? defaultFrame;
      for (final shape in state.shapes.values) {
        if (shape is FrameShape) {
          defaultFrame = shape;
          break;
        }
      }
      final frameId = defaultFrame?.id;

      final sortOrder = _nextSortOrderForNewShape(
        shapes: state.shapes,
        parentId: null,
        frameId: frameId,
      );

      final newShape = TextShape(
        id: newId,
        name: 'Text',
        x: canvasPoint.dx,
        y: canvasPoint.dy,
        textWidth: 200,
        textHeight: 24,
        text: '',
        sortOrder: sortOrder,
        fills: const [ShapeFill(color: 0xFFE6EDF3)],
        frameId: frameId,
      );

      final newShapes = Map<String, Shape>.from(state.shapes)
        ..[newId] = newShape;
      final newDraftIds = Set<String>.from(state.draftTextShapeIds)..add(newId);
      final expanded = Set<String>.from(state.expandedLayerIds);
      if (frameId != null) {
        expanded.add(frameId);
      }

      emit(
        state.copyWith(
          shapes: newShapes,
          selectedShapeIds: [newId],
          expandedLayerIds: expanded,
          editingTextShapeId: newId,
          draftTextShapeIds: newDraftIds,
          interactionMode: InteractionMode.idle,
          clearDragStart: true,
          clearCurrentPointer: true,
          clearDragOffset: true,
          clearSnap: true,
        ),
      );

      // Do NOT push undo state yet; we push only on commit.
      return;
    }

    // Drag-to-create tools
    if (event.tool != CanvasPointerTool.select &&
        state.interactionMode != InteractionMode.drawing) {
      final newId = _uuid.v4();

      FrameShape? defaultFrame;
      for (final shape in state.shapes.values) {
        if (shape is FrameShape) {
          defaultFrame = shape;
          break;
        }
      }
      final frameId = defaultFrame?.id;

      final sortOrder = _nextSortOrderForNewShape(
        shapes: state.shapes,
        parentId: null,
        frameId: frameId,
      );

      final newShape = switch (event.tool) {
        CanvasPointerTool.drawRectangle => RectangleShape(
            id: newId,
            name: 'Rectangle',
            x: canvasPoint.dx,
            y: canvasPoint.dy,
            rectWidth: 1,
            rectHeight: 1,
            sortOrder: sortOrder,
            fills: const [ShapeFill(color: 0xFF3B82F6)],
            strokes: const [ShapeStroke(color: 0xFF1D4ED8, width: 2)],
            frameId: frameId,
          ),
        CanvasPointerTool.drawEllipse => EllipseShape(
            id: newId,
            name: 'Ellipse',
            x: canvasPoint.dx,
            y: canvasPoint.dy,
            ellipseWidth: 1,
            ellipseHeight: 1,
            sortOrder: sortOrder,
            fills: const [ShapeFill(color: 0xFF3B82F6)],
            strokes: const [ShapeStroke(color: 0xFF1D4ED8, width: 2)],
            frameId: frameId,
          ),
        CanvasPointerTool.drawFrame => FrameShape(
            id: newId,
            name: 'Frame',
            x: canvasPoint.dx,
            y: canvasPoint.dy,
            frameWidth: 1,
            frameHeight: 1,
            sortOrder: sortOrder,
            fills: const [ShapeFill(color: 0xFF2D2D2D)],
            strokes: const [ShapeStroke(color: 0xFF404040)],
          ),
        CanvasPointerTool.drawText => throw StateError('Unreachable'),
        CanvasPointerTool.select => throw StateError('Unreachable'),
      };

      final newShapes = Map<String, Shape>.from(state.shapes)
        ..[newId] = newShape;
      final expanded = Set<String>.from(state.expandedLayerIds);
      if (frameId != null) {
        expanded.add(frameId);
      }

      emit(
        state.copyWith(
          shapes: newShapes,
          selectedShapeIds: [newId],
          expandedLayerIds: expanded,
          interactionMode: InteractionMode.drawing,
          drawingShapeId: newId,
          drawingPresetSize: event.tool == CanvasPointerTool.drawFrame &&
                  event.initialWidth != null &&
                  event.initialHeight != null
              ? Size(event.initialWidth!, event.initialHeight!)
              : null,
          dragStart: canvasPoint,
          currentPointer: canvasPoint,
          clearDragOffset: true,
          clearSnap: true,
        ),
      );
      return;
    }

    // First, check if we hit a handle when shapes are selected
    if (state.hasSelection) {
      // Check corner radius handles first (for single rectangle)
      final cornerRadiusHandle = _hitTestCornerRadiusHandle(screenPoint);
      if (cornerRadiusHandle != null) {
        emit(
          state.copyWith(
            interactionMode: InteractionMode.adjustingCornerRadius,
            activeCornerIndex: cornerRadiusHandle.index,
            dragStart: canvasPoint,
            currentPointer: canvasPoint,
          ),
        );
        return;
      }

      // Check resize/rotate handles
      final handle = _hitTestHandle(screenPoint);
      if (handle != null) {
        if (handle.position == HandlePosition.rotation) {
          // Start rotation - calculate initial angle from selection center
          final bounds = state.selectionRect;
          final center = bounds?.center ?? canvasPoint;
          final initialAngle = _calculateRotationAngle(canvasPoint, center);
          emit(
            state.copyWith(
              interactionMode: InteractionMode.rotating,
              activeHandle: handle.position.name,
              dragStart: canvasPoint,
              currentPointer: canvasPoint,
              originalShapeBounds: bounds,
              originalShapes: Map.from(state.shapes),
              initialRotationAngle: initialAngle,
            ),
          );
        } else {
          // Start resize - store original shapes for relative position calculation
          final bounds = state.selectionRect;
          final resizeOrigin = _getResizeOrigin(handle.position, bounds);
          emit(
            state.copyWith(
              interactionMode: InteractionMode.resizing,
              activeHandle: handle.position.name,
              resizeOrigin: resizeOrigin,
              dragStart: canvasPoint,
              currentPointer: canvasPoint,
              originalShapeBounds: bounds,
              originalShapes: Map.from(state.shapes),
            ),
          );
        }
        return;
      }
    }

    // Hit test to find shape under pointer
    final hitShape = HitTest.findTopShapeAtPoint(canvasPoint, state.shapeList);

    if (hitShape != null) {
      // Check if shift is held for multi-select
      final addToSelection = event.shiftPressed;

      if (addToSelection) {
        // Toggle selection
        if (state.selectedShapeIds.contains(hitShape.id)) {
          _endSnapSession();
          emit(
            state.copyWith(
              selectedShapeIds: state.selectedShapeIds
                  .where((id) => id != hitShape.id)
                  .toList(),
              interactionMode: InteractionMode.idle,
              clearDragStart: true,
              clearCurrentPointer: true,
            ),
          );
        } else {
          final newSelection = [...state.selectedShapeIds, hitShape.id];
          _beginSnapSession(newSelection.toSet());
          emit(
            state.copyWith(
              selectedShapeIds: newSelection,
              expandedLayerIds: _expandAncestorsForShapes(newSelection),
              interactionMode: InteractionMode.movingShapes,
              dragStart: canvasPoint,
              currentPointer: canvasPoint,
            ),
          );
        }
      } else {
        // Single selection - shape clicked, start moving
        final isAlreadySelected = state.selectedShapeIds.contains(hitShape.id);
        final newSelection =
            isAlreadySelected ? state.selectedShapeIds : [hitShape.id];

        _beginSnapSession(newSelection.toSet());
        emit(
          state.copyWith(
            selectedShapeIds: newSelection,
            expandedLayerIds: _expandAncestorsForShapes(newSelection),
            interactionMode: InteractionMode.movingShapes,
            dragStart: canvasPoint,
            currentPointer: canvasPoint,
          ),
        );
      }
    } else {
      // No shape hit - start marquee selection
      _endSnapSession();
      emit(
        state.copyWith(
          interactionMode: InteractionMode.dragging,
          dragStart: canvasPoint,
          currentPointer: canvasPoint,
          selectedShapeIds: [], // Clear selection
        ),
      );
    }
  }

  void _onTextEditCommitted(
    TextEditCommitted event,
    Emitter<CanvasState> emit,
  ) {
    final existing = state.shapes[event.shapeId];
    if (existing is! TextShape) {
      emit(state.copyWith(clearEditingTextShapeId: true));
      return;
    }

    final trimmed = event.text;
    final isDraft = state.draftTextShapeIds.contains(event.shapeId);
    if (trimmed.trim().isEmpty) {
      // For draft text (just created), treat empty commit as cancel: remove it
      // and do not sync/persist anything.
      if (isDraft) {
        final newShapes = Map<String, Shape>.from(state.shapes)
          ..remove(event.shapeId);
        final newDraftIds = Set<String>.from(state.draftTextShapeIds)
          ..remove(event.shapeId);

        emit(
          state.copyWith(
            shapes: newShapes,
            draftTextShapeIds: newDraftIds,
            selectedShapeIds: const [],
            clearEditingTextShapeId: true,
          ),
        );
        return;
      }

      // Non-draft: empty commit deletes the existing text shape.
      final newShapes = Map<String, Shape>.from(state.shapes)
        ..remove(event.shapeId);

      _notifyRepositoryShapeDeleted(event.shapeId);

      final newSelection = state.selectedShapeIds
          .where((id) => id != event.shapeId)
          .toList(growable: false);

      emit(
        state.copyWith(
          shapes: newShapes,
          selectedShapeIds: newSelection,
          clearEditingTextShapeId: true,
        ),
      );

      _pushUndoState(newShapes);
      return;
    }

    final updated = existing.copyWith(
      text: trimmed,
      // Penpot-like: don't auto-shrink the box on commit.
      // Keep the user's current box size, only grow when needed.
      textWidth: math.max(
        existing.textWidth <= 1 ? 200.0 : existing.textWidth,
        event.width,
      ),
      textHeight: math.max(
        existing.textHeight <= 1 ? 24.0 : existing.textHeight,
        event.height,
      ),
    );

    final newShapes = Map<String, Shape>.from(state.shapes)
      ..[event.shapeId] = updated;

    emit(
      state.copyWith(
        shapes: newShapes,
        clearEditingTextShapeId: true,
      ),
    );

    if (isDraft) {
      _notifyRepositoryShapeAdded(updated);
      final newDraftIds = Set<String>.from(state.draftTextShapeIds)
        ..remove(event.shapeId);
      emit(state.copyWith(draftTextShapeIds: newDraftIds));
    } else {
      _notifyRepositoryShapeUpdated(updated);
    }
    _pushUndoState(newShapes);
  }

  void _onTextEditCanceled(
    TextEditCanceled event,
    Emitter<CanvasState> emit,
  ) {
    final existing = state.shapes[event.shapeId];
    final isDraft = state.draftTextShapeIds.contains(event.shapeId);
    if (existing is TextShape && isDraft) {
      final newShapes = Map<String, Shape>.from(state.shapes)
        ..remove(event.shapeId);
      final newDraftIds = Set<String>.from(state.draftTextShapeIds)
        ..remove(event.shapeId);
      emit(
        state.copyWith(
          shapes: newShapes,
          draftTextShapeIds: newDraftIds,
          selectedShapeIds: const [],
          clearEditingTextShapeId: true,
        ),
      );
      return;
    }

    emit(state.copyWith(clearEditingTextShapeId: true));
  }

  void _onPointerMove(
    PointerMove event,
    Emitter<CanvasState> emit,
  ) {
    final screenPoint = Offset(event.x, event.y);
    final canvasPoint = _screenToCanvas(Offset(event.x, event.y));

    // Handle drag-to-create shape updates
    if (state.interactionMode == InteractionMode.drawing &&
        state.drawingShapeId != null &&
        state.dragStart != null) {
      final shapeId = state.drawingShapeId!;
      final shape = state.shapes[shapeId];
      if (shape == null) return;

      final start = state.dragStart!;

      // If a preset is armed, a simple click should apply it.
      // As soon as the user drags beyond a small threshold, treat it as
      // custom drag-to-create and disarm the preset.
      const presetDisarmThreshold = 3.0;
      final shouldDisarmPreset = state.drawingPresetSize != null &&
          (canvasPoint - start).distance > presetDisarmThreshold;

      final dx = canvasPoint.dx - start.dx;
      final dy = canvasPoint.dy - start.dy;

      var width = dx.abs();
      var height = dy.abs();

      if (event.shiftPressed) {
        final size = math.max(width, height);
        width = size;
        height = size;
      }

      width = width.clamp(1.0, double.infinity);
      height = height.clamp(1.0, double.infinity);

      final left = start.dx + (dx < 0 ? -width : 0);
      final top = start.dy + (dy < 0 ? -height : 0);

      final newShapes = Map<String, Shape>.from(state.shapes);
      if (shape is RectangleShape) {
        newShapes[shapeId] = shape.copyWith(
          x: left,
          y: top,
          rectWidth: width,
          rectHeight: height,
        );
      } else if (shape is EllipseShape) {
        newShapes[shapeId] = shape.copyWith(
          x: left,
          y: top,
          ellipseWidth: width,
          ellipseHeight: height,
        );
      } else if (shape is FrameShape) {
        newShapes[shapeId] = shape.copyWith(
          x: left,
          y: top,
          frameWidth: width,
          frameHeight: height,
        );
      }

      emit(
        state.copyWith(
          shapes: newShapes,
          currentPointer: canvasPoint,
          clearDrawingPresetSize: shouldDisarmPreset,
        ),
      );
      return;
    }

    // Handle resizing
    if (state.interactionMode == InteractionMode.resizing &&
        state.activeHandle != null &&
        state.resizeOrigin != null &&
        state.originalShapeBounds != null) {
      final handle = HandlePosition.values.firstWhere(
        (h) => h.name == state.activeHandle,
        orElse: () => HandlePosition.bottomRight,
      );
      final newShapes = _calculateResize(
        canvasPoint,
        handle,
        state.resizeOrigin!,
        state.originalShapeBounds!,
      );
      emit(
        state.copyWith(
          shapes: newShapes,
          currentPointer: canvasPoint,
        ),
      );
      return;
    }

    // Handle rotation
    if (state.interactionMode == InteractionMode.rotating &&
        state.originalShapeBounds != null &&
        state.originalShapes != null) {
      final center = state.originalShapeBounds!.center;
      // Calculate current angle and delta from initial
      final currentAngle = _calculateRotationAngle(canvasPoint, center);
      var deltaAngle = currentAngle - (state.initialRotationAngle ?? 0);

      // If shift is pressed, snap to 15° increments
      if (event.shiftPressed) {
        deltaAngle = (deltaAngle / 15).round() * 15.0;
      }

      // Convert delta angle to radians for matrix
      final deltaRadians = deltaAngle * math.pi / 180;

      // Apply rotation to each selected shape
      final newShapes = Map<String, Shape>.from(state.shapes);
      final selectedIds = state.selectedShapeIds;
      final originalShapes = state.originalShapes!;

      for (final shapeId in selectedIds) {
        final originalShape = originalShapes[shapeId];
        if (originalShape == null) continue;
        if (originalShape.blocked) continue;

        // Calculate rotation center
        Offset rotationCenter;
        if (selectedIds.length == 1) {
          // Single shape: rotate around its own center
          rotationCenter = originalShape.bounds.center;
        } else {
          // Multi-select: rotate around selection center
          rotationCenter = center;
        }

        // Create rotation matrix around the center
        final rotationMatrix = Matrix2D.rotationAt(
          deltaRadians,
          rotationCenter.dx,
          rotationCenter.dy,
        );

        // Multiply original transform with rotation
        final newTransform = originalShape.transform * rotationMatrix;

        // Calculate new rotation value (original rotation + delta)
        final newRotation = (originalShape.rotation + deltaAngle) % 360;

        // Update shape with new transform and rotation field
        newShapes[shapeId] = originalShape.copyWith(
          transform: newTransform,
          rotation: newRotation,
        );
      }

      emit(
        state.copyWith(
          shapes: newShapes,
          currentPointer: canvasPoint,
        ),
      );
      return;
    }

    // Handle corner radius adjustment
    if (state.interactionMode == InteractionMode.adjustingCornerRadius &&
        state.activeCornerIndex != null &&
        state.selectedShapes.length == 1) {
      final shape = state.selectedShapes.first;
      if (shape is RectangleShape) {
        if (shape.blocked) return;
        final newRadius = _calculateCornerRadius(
          canvasPoint,
          state.activeCornerIndex!,
          shape,
        );
        final newShapes = Map<String, Shape>.from(state.shapes);
        // Apply to all corners for uniform radius
        newShapes[shape.id] = shape.copyWith(
          r1: newRadius,
          r2: newRadius,
          r3: newRadius,
          r4: newRadius,
        );
        emit(
          state.copyWith(
            shapes: newShapes,
            currentPointer: canvasPoint,
          ),
        );
      }
      return;
    }

    // Handle shape movement - only update dragOffset, not shapes
    if (state.interactionMode == InteractionMode.movingShapes &&
        state.dragStart != null &&
        state.selectedShapeIds.isNotEmpty) {
      // Calculate total offset from drag start
      var newDragOffset = Offset(
        canvasPoint.dx - state.dragStart!.dx,
        canvasPoint.dy - state.dragStart!.dy,
      );

      // Perform snap detection (cached + throttled)
      final snapResult = _detectSnap(newDragOffset);
      if (snapResult.hasSnap) {
        newDragOffset = newDragOffset + snapResult.snapOffset;
      }

      emit(
        state.copyWith(
          dragOffset: newDragOffset,
          currentPointer: canvasPoint,
          snapLines: snapResult.snapLines,
          snapPoints: snapResult.snapPoints,
        ),
      );
    } else {
      // Throttle hover hit-testing on web/desktop pointer-move.
      if (!_shouldRecomputeHover(screenPoint)) {
        emit(state.copyWith(currentPointer: canvasPoint));
        return;
      }

      // Hover corner-radius handles (single rectangle selection).
      // Only when not actively dragging the radius.
      _CornerRadiusHit? hoveredCorner;
      if (state.interactionMode != InteractionMode.adjustingCornerRadius &&
          state.selectedShapes.length == 1 &&
          state.selectedShapes.first is RectangleShape) {
        hoveredCorner = _hitTestCornerRadiusHandle(screenPoint);
      }

      // Hit test to find shape under pointer for hover highlight
      final hoveredShape =
          HitTest.findTopShapeAtPoint(canvasPoint, state.shapeList);
      final newHoveredId = hoveredShape?.id;

      final nextHoveredCornerIndex = hoveredCorner?.index;

      // Only emit if hovered shape changed
      if (newHoveredId != state.hoveredShapeId ||
          nextHoveredCornerIndex != state.hoveredCornerIndex) {
        if (newHoveredId == null) {
          emit(
            state.copyWith(
              currentPointer: canvasPoint,
              clearHoveredShapeId: true,
              hoveredCornerIndex: nextHoveredCornerIndex,
              clearHoveredCornerIndex: nextHoveredCornerIndex == null,
            ),
          );
        } else {
          emit(
            state.copyWith(
              currentPointer: canvasPoint,
              hoveredShapeId: newHoveredId,
              hoveredCornerIndex: nextHoveredCornerIndex,
              clearHoveredCornerIndex: nextHoveredCornerIndex == null,
            ),
          );
        }
      } else {
        emit(state.copyWith(currentPointer: canvasPoint));
      }
    }
  }

  void _onPointerUp(
    PointerUp event,
    Emitter<CanvasState> emit,
  ) {
    // Handle drag-to-create completion
    if (state.interactionMode == InteractionMode.drawing &&
        state.drawingShapeId != null) {
      final shapeId = state.drawingShapeId!;
      var nextShapes = state.shapes;
      final createdShape = nextShapes[shapeId];

      // Click-to-create preset frames (no drag).
      if (createdShape is FrameShape &&
          state.drawingPresetSize != null &&
          state.dragStart != null &&
          state.currentPointer != null) {
        const clickThreshold = 3.0;
        final distance = (state.currentPointer! - state.dragStart!).distance;
        if (distance <= clickThreshold) {
          nextShapes = Map<String, Shape>.from(nextShapes)
            ..[shapeId] = createdShape.copyWith(
              frameWidth: state.drawingPresetSize!.width,
              frameHeight: state.drawingPresetSize!.height,
            );
        }
      }

      final finalShape = nextShapes[shapeId];
      if (finalShape != null) {
        _notifyRepositoryShapeAdded(finalShape);
      }

      _pushUndoState(nextShapes);
      emit(
        state.copyWith(
          shapes: nextShapes,
          interactionMode: InteractionMode.idle,
          clearDragStart: true,
          clearCurrentPointer: true,
          clearDrawingShapeId: true,
          clearDrawingPresetSize: true,
          clearSnap: true,
        ),
      );
      return;
    }

    // Handle resize completion
    if (state.interactionMode == InteractionMode.resizing) {
      // Shapes were already updated in real-time, just push to undo stack
      _pushUndoState(state.shapes);
      emit(
        state.copyWith(
          interactionMode: InteractionMode.idle,
          clearDragStart: true,
          clearCurrentPointer: true,
          clearActiveHandle: true,
          clearResizeOrigin: true,
          clearOriginalShapeBounds: true,
          clearOriginalShapes: true,
        ),
      );
      return;
    }

    // Handle rotation completion
    if (state.interactionMode == InteractionMode.rotating) {
      // Commit rotation transforms - shapes were already updated in real-time
      _pushUndoState(state.shapes);
      emit(
        state.copyWith(
          interactionMode: InteractionMode.idle,
          clearDragStart: true,
          clearCurrentPointer: true,
          clearActiveHandle: true,
          clearOriginalShapeBounds: true,
          clearOriginalShapes: true,
          clearInitialRotationAngle: true,
        ),
      );
      return;
    }

    // Handle corner radius adjustment completion
    if (state.interactionMode == InteractionMode.adjustingCornerRadius) {
      // Shapes were already updated in real-time, just push to undo stack
      _pushUndoState(state.shapes);
      emit(
        state.copyWith(
          interactionMode: InteractionMode.idle,
          clearDragStart: true,
          clearCurrentPointer: true,
          clearActiveCornerIndex: true,
        ),
      );
      return;
    }

    // Check if we were doing marquee selection
    if (state.interactionMode == InteractionMode.dragging &&
        state.dragRect != null) {
      // Find shapes in the marquee rectangle
      final shapesInRect = HitTest.findShapesInRect(
        state.dragRect!,
        state.shapeList,
      );
      final selectedIds = shapesInRect.map((s) => s.id).toList();

      emit(
        state.copyWith(
          interactionMode: InteractionMode.idle,
          selectedShapeIds: selectedIds,
          expandedLayerIds: _expandAncestorsForShapes(selectedIds),
          clearDragStart: true,
          clearCurrentPointer: true,
        ),
      );
    } else if (state.interactionMode == InteractionMode.movingShapes) {
      _endSnapSession();
      // Finished moving shapes - commit the drag offset to shape positions
      if (state.dragOffset != null && state.selectedShapeIds.isNotEmpty) {
        Rect? selectionRectFor(Map<String, Shape> shapes, List<String> ids) {
          if (ids.isEmpty) return null;
          double? minX, minY, maxX, maxY;
          for (final id in ids) {
            final s = shapes[id];
            if (s == null) continue;
            final bounds = s.bounds;
            final corners = [
              s.transformPoint(Offset(bounds.left, bounds.top)),
              s.transformPoint(Offset(bounds.right, bounds.top)),
              s.transformPoint(Offset(bounds.right, bounds.bottom)),
              s.transformPoint(Offset(bounds.left, bounds.bottom)),
            ];
            for (final c in corners) {
              minX = minX == null ? c.dx : math.min(minX, c.dx);
              minY = minY == null ? c.dy : math.min(minY, c.dy);
              maxX = maxX == null ? c.dx : math.max(maxX, c.dx);
              maxY = maxY == null ? c.dy : math.max(maxY, c.dy);
            }
          }
          if (minX == null || minY == null || maxX == null || maxY == null) {
            return null;
          }
          return Rect.fromLTWH(minX, minY, maxX - minX, maxY - minY);
        }

        final newShapes = Map<String, Shape>.from(state.shapes);
        final updatedShapeIds = <String>{};

        Shape movedBy(Shape shape, Offset delta) {
          final hasRotation = shape.rotation != 0;
          if (hasRotation) {
            final newTransform = shape.transform.copyWith(
              e: shape.transform.e + delta.dx,
              f: shape.transform.f + delta.dy,
            );
            return shape.copyWith(transform: newTransform);
          }
          return shape.moveBy(delta.dx, delta.dy);
        }

        Set<String> collectFrameDescendants(Set<String> rootFrameIds) {
          final result = <String>{};
          final queue = <String>[...rootFrameIds];
          final seenFrames = <String>{...rootFrameIds};

          while (queue.isNotEmpty) {
            final frameId = queue.removeLast();
            for (final entry in newShapes.entries) {
              final shape = entry.value;
              if (shape.frameId != frameId) continue;
              final id = entry.key;
              if (result.add(id) && shape is FrameShape) {
                if (seenFrames.add(id)) {
                  queue.add(id);
                }
              }
            }
          }

          return result;
        }

        Set<String> collectGroupDescendants(Set<String> rootGroupIds) {
          final result = <String>{};
          final queue = <String>[...rootGroupIds];

          while (queue.isNotEmpty) {
            final groupId = queue.removeLast();
            for (final entry in newShapes.entries) {
              final shape = entry.value;
              if (shape.parentId != groupId) continue;
              final id = entry.key;
              if (result.add(id) && shape is GroupShape) {
                queue.add(id);
              }
            }
          }

          return result;
        }

        final selectedSet = state.selectedShapeIds.toSet();

        // Move selected shapes.
        for (final shapeId in state.selectedShapeIds) {
          final shape = newShapes[shapeId];
          if (shape == null) continue;
          if (shape.blocked) continue;
          newShapes[shapeId] = movedBy(shape, state.dragOffset!);
          updatedShapeIds.add(shapeId);
        }

        // If groups are moved, also move their descendants.
        final movedGroupIds = <String>{
          for (final id in state.selectedShapeIds)
            if (newShapes[id] is GroupShape &&
                (newShapes[id]?.blocked ?? false) == false)
              id,
        };

        if (movedGroupIds.isNotEmpty) {
          final descendants = collectGroupDescendants(movedGroupIds);
          for (final id in descendants) {
            if (selectedSet.contains(id)) continue; // avoid double-moving
            final shape = newShapes[id];
            if (shape == null) continue;
            newShapes[id] = movedBy(shape, state.dragOffset!);
            updatedShapeIds.add(id);
          }
        }

        // If frames were moved (directly selected OR moved as a group
        // descendant), also move their contents so they behave like
        // frame-local coordinates (Penpot/Figma behavior).
        final movedFrameIds = <String>{
          for (final id in updatedShapeIds)
            if (newShapes[id] is FrameShape) id,
        };

        if (movedFrameIds.isNotEmpty) {
          final descendants = collectFrameDescendants(movedFrameIds);
          for (final id in descendants) {
            if (selectedSet.contains(id)) continue; // avoid double-moving
            final shape = newShapes[id];
            if (shape == null) continue;
            newShapes[id] = movedBy(shape, state.dragOffset!);
            updatedShapeIds.add(id);
          }
        }

        final dropCenter =
            selectionRectFor(newShapes, state.selectedShapeIds)?.center;

        // Figma-like behavior: if the selection center ends up inside a frame,
        // reparent all selected (non-frame) shapes to that frame.
        // We keep absolute x/y, so there is no coordinate conversion.
        final selectionContainsFrame = state.selectedShapeIds
            .map((id) => newShapes[id])
            .any((s) => s is FrameShape);

        if (!selectionContainsFrame && dropCenter != null) {
          final destinationFrame = _findTopFrameContainingPoint(
            point: dropCenter,
            shapesInZOrder: newShapes.values.toList(growable: false),
            excludeIds: state.selectedShapeIds.toSet(),
          );
          final destinationFrameId = destinationFrame?.id;

          for (final shapeId in state.selectedShapeIds) {
            final shape = newShapes[shapeId];
            if (shape == null || shape is FrameShape) {
              continue;
            }
            if (shape.blocked) {
              continue;
            }

            if (shape.frameId != destinationFrameId) {
              // Reparenting into a frame removes any group parent.
              newShapes[shapeId] = shape.copyWith(
                frameId: destinationFrameId,
                parentId: null,
              );
              updatedShapeIds.add(shapeId);
            }
          }

          // If groups were reparented, propagate frameId to descendants.
          final movedGroups = <String>{
            for (final id in state.selectedShapeIds)
              if (newShapes[id] is GroupShape &&
                  (newShapes[id]?.blocked ?? false) == false)
                id,
          };

          if (movedGroups.isNotEmpty) {
            final descendants = collectGroupDescendants(movedGroups);
            for (final id in descendants) {
              if (selectedSet.contains(id)) continue;
              final child = newShapes[id];
              if (child == null) continue;
              if (child.frameId != destinationFrameId) {
                newShapes[id] = child.copyWith(frameId: destinationFrameId);
                updatedShapeIds.add(id);
              }
            }
          }
        }

        // Remove any groups that became empty due to move/reparent.
        final pruneResult = _pruneEmptyGroups(newShapes);
        final prunedShapes = pruneResult.shapes;
        if (pruneResult.deletedGroupIds.isNotEmpty) {
          for (final id in pruneResult.deletedGroupIds) {
            _notifyRepositoryShapeDeleted(id);
          }
        }

        // Expand the destination frame chain so the layer tree updates visibly.
        final expanded = _expandAncestorsForShapesIn(
          prunedShapes,
          state.selectedShapeIds,
          state.expandedLayerIds,
        );

        // Queue sync updates for changed shapes.
        for (final id in updatedShapeIds) {
          final updated = prunedShapes[id];
          if (updated != null) {
            _notifyRepositoryShapeUpdated(updated);
          }
        }

        final cleanedExpanded = Set<String>.from(expanded)
          ..removeAll(pruneResult.deletedGroupIds);

        emit(
          state.copyWith(
            shapes: prunedShapes,
            expandedLayerIds: cleanedExpanded,
            interactionMode: InteractionMode.idle,
            clearDragStart: true,
            clearCurrentPointer: true,
            clearDragOffset: true,
            clearSnap: true,
          ),
        );
        // Push to undo stack after shapes are moved
        _pushUndoState(prunedShapes);
      } else {
        emit(
          state.copyWith(
            interactionMode: InteractionMode.idle,
            clearDragStart: true,
            clearCurrentPointer: true,
            clearDragOffset: true,
            clearSnap: true,
          ),
        );
      }
    } else {
      emit(
        state.copyWith(
          interactionMode: InteractionMode.idle,
          clearDragStart: true,
          clearCurrentPointer: true,
        ),
      );
    }
  }

  /// Find the top-most frame (by current paint/z order) that contains [point]
  /// in canvas coordinates.
  ///
  /// Note: This checks the frame bounds, not the label hit area (unlike
  /// [HitTest.hitTestShape] for frames).
  FrameShape? _findTopFrameContainingPoint({
    required Offset point,
    required List<Shape> shapesInZOrder,
    required Set<String> excludeIds,
  }) {
    for (var i = shapesInZOrder.length - 1; i >= 0; i--) {
      final shape = shapesInZOrder[i];
      if (shape is! FrameShape) continue;
      if (shape.hidden) continue;
      if (excludeIds.contains(shape.id)) continue;

      final bounds = _getTransformedBounds(shape);
      if (bounds.contains(point)) {
        return shape;
      }
    }
    return null;
  }

  /// Axis-aligned bounding box of a shape after applying its transform.
  ///
  /// Mirrors the logic in HitTest's internal bounds transform.
  Rect _getTransformedBounds(Shape shape) {
    final bounds = shape.bounds;

    final corners = [
      shape.transformPoint(Offset(bounds.left, bounds.top)),
      shape.transformPoint(Offset(bounds.right, bounds.top)),
      shape.transformPoint(Offset(bounds.right, bounds.bottom)),
      shape.transformPoint(Offset(bounds.left, bounds.bottom)),
    ];

    var minX = corners[0].dx;
    var maxX = corners[0].dx;
    var minY = corners[0].dy;
    var maxY = corners[0].dy;

    for (final corner in corners) {
      if (corner.dx < minX) minX = corner.dx;
      if (corner.dx > maxX) maxX = corner.dx;
      if (corner.dy < minY) minY = corner.dy;
      if (corner.dy > maxY) maxY = corner.dy;
    }

    return Rect.fromLTWH(minX, minY, maxX - minX, maxY - minY);
  }

  /// Expand all ancestors (frameId / parentId chain) for the given shapes,
  /// using [shapes] rather than [state.shapes].
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

  void _onSelectionCleared(
    SelectionCleared event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(selectedShapeIds: [], clearHoveredCornerIndex: true));
  }

  void _onShapesReparented(
    ShapesReparented event,
    Emitter<CanvasState> emit,
  ) {
    if (event.shapeIds.isEmpty) return;

    final destinationFrameId = event.destinationFrameId;
    if (destinationFrameId != null) {
      final destinationFrame = state.shapes[destinationFrameId];
      if (destinationFrame is! FrameShape) {
        return;
      }
    }

    final newShapes = Map<String, Shape>.from(state.shapes);
    final updatedShapeIds = <String>{};

    Set<String> collectGroupDescendants(Set<String> rootGroupIds) {
      final result = <String>{};
      final queue = <String>[...rootGroupIds];

      while (queue.isNotEmpty) {
        final groupId = queue.removeLast();
        for (final entry in newShapes.entries) {
          final shape = entry.value;
          if (shape.parentId != groupId) continue;
          final id = entry.key;
          if (result.add(id) && shape is GroupShape) {
            queue.add(id);
          }
        }
      }

      return result;
    }

    final movedGroupIds = <String>{};

    for (final id in event.shapeIds) {
      final shape = newShapes[id];
      if (shape == null) continue;
      if (shape is FrameShape) continue;
      if (shape.blocked) continue;

      if (shape.frameId != destinationFrameId || shape.parentId != null) {
        // Reparenting into a frame/root removes any group parent.
        newShapes[id] = shape.copyWith(
          frameId: destinationFrameId,
          parentId: null,
        );
        updatedShapeIds.add(id);
      }

      if (shape is GroupShape) {
        movedGroupIds.add(id);
      }
    }

    // Ensure descendants of moved groups inherit the new frameId.
    if (movedGroupIds.isNotEmpty) {
      final descendants = collectGroupDescendants(movedGroupIds);
      for (final id in descendants) {
        final shape = newShapes[id];
        if (shape == null) continue;
        if (shape.frameId != destinationFrameId) {
          newShapes[id] = shape.copyWith(frameId: destinationFrameId);
          updatedShapeIds.add(id);
        }
      }
    }

    if (updatedShapeIds.isEmpty) return;

    final pruneResult = _pruneEmptyGroups(newShapes);
    final prunedShapes = pruneResult.shapes;
    if (pruneResult.deletedGroupIds.isNotEmpty) {
      for (final id in pruneResult.deletedGroupIds) {
        _notifyRepositoryShapeDeleted(id);
      }
    }

    // Expand destination frame chain so the moved items remain visible.
    final expanded = _expandAncestorsForShapesIn(
      prunedShapes,
      updatedShapeIds.toList(growable: false),
      state.expandedLayerIds,
    );

    for (final id in updatedShapeIds) {
      final updated = prunedShapes[id];
      if (updated != null) {
        _notifyRepositoryShapeUpdated(updated);
      }
    }

    final cleanedExpanded = Set<String>.from(expanded)
      ..removeAll(pruneResult.deletedGroupIds);

    final cleanedSelection = state.selectedShapeIds
        .where((id) => !pruneResult.deletedGroupIds.contains(id))
        .toList(growable: false);

    emit(
      state.copyWith(
        shapes: prunedShapes,
        expandedLayerIds: cleanedExpanded,
        selectedShapeIds: cleanedSelection,
      ),
    );
    _pushUndoState(prunedShapes);
  }

  void _onCreateGroupFromSelection(
    CreateGroupFromSelection event,
    Emitter<CanvasState> emit,
  ) {
    if (state.selectedShapeIds.length < 2) return;

    final selected = state.selectedShapeIds
        .map((id) => state.shapes[id])
        .whereType<Shape>()
        .where((s) => s is! FrameShape)
        .where((s) => !s.blocked)
        .toList(growable: false);

    if (selected.length < 2) return;

    // Disallow grouping across frames.
    final frameIds = selected.map((s) => s.frameId).toSet();
    if (frameIds.length > 1) return;
    final groupFrameId = frameIds.isEmpty ? null : frameIds.first;

    // Keep group at the same hierarchy level if possible.
    final parentIds = selected.map((s) => s.parentId).toSet();
    final groupParentId = parentIds.length == 1 ? parentIds.first : null;

    Rect? union;
    for (final shape in selected) {
      final b = _getTransformedBounds(shape);
      union = union == null ? b : union.expandToInclude(b);
    }
    if (union == null) return;

    final groupId = _uuid.v4();

    final groupSortOrder = _nextSortOrderForNewShape(
      shapes: state.shapes,
      parentId: groupParentId,
      frameId: groupFrameId,
    );
    final group = GroupShape(
      id: groupId,
      name: 'Group',
      x: union.left,
      y: union.top,
      groupWidth: union.width,
      groupHeight: union.height,
      frameId: groupFrameId,
      parentId: groupParentId,
      sortOrder: groupSortOrder,
    );

    final newShapes = Map<String, Shape>.from(state.shapes);
    newShapes[groupId] = group;
    _notifyRepositoryShapeAdded(group);

    for (final shape in selected) {
      newShapes[shape.id] = shape.copyWith(parentId: groupId);
      final updated = newShapes[shape.id];
      if (updated != null) {
        _notifyRepositoryShapeUpdated(updated);
      }
    }

    final expandedWithGroup = Set<String>.from(state.expandedLayerIds)
      ..add(groupId);
    final expanded = _expandAncestorsForShapesIn(
      newShapes,
      [groupId],
      expandedWithGroup,
    );

    emit(
      state.copyWith(
        shapes: newShapes,
        selectedShapeIds: [groupId],
        expandedLayerIds: expanded,
      ),
    );

    _pushUndoState(newShapes);
  }

  void _onShapeAdded(
    ShapeAdded event,
    Emitter<CanvasState> emit,
  ) {
    final newShapes = Map<String, Shape>.from(state.shapes);
    newShapes[event.shape.id] = event.shape;
    _notifyRepositoryShapeAdded(event.shape);
    emit(state.copyWith(shapes: newShapes));
    _pushUndoState(newShapes);
  }

  void _onShapesAdded(
    ShapesAdded event,
    Emitter<CanvasState> emit,
  ) {
    final newShapes = Map<String, Shape>.from(state.shapes);
    for (final shape in event.shapes) {
      newShapes[shape.id] = shape;
      _notifyRepositoryShapeAdded(shape);
    }
    emit(state.copyWith(shapes: newShapes));
    _pushUndoState(newShapes);
  }

  void _onShapeRemoved(
    ShapeRemoved event,
    Emitter<CanvasState> emit,
  ) {
    final newShapes = Map<String, Shape>.from(state.shapes);
    newShapes.remove(event.shapeId);
    _notifyRepositoryShapeDeleted(event.shapeId);

    final pruneResult = _pruneEmptyGroups(newShapes);
    final prunedShapes = pruneResult.shapes;
    if (pruneResult.deletedGroupIds.isNotEmpty) {
      for (final id in pruneResult.deletedGroupIds) {
        _notifyRepositoryShapeDeleted(id);
      }
    }

    // Also remove from selection
    final removedAll = <String>{event.shapeId, ...pruneResult.deletedGroupIds};
    final newSelection =
        state.selectedShapeIds.where((id) => !removedAll.contains(id)).toList();

    final cleanedExpanded = Set<String>.from(state.expandedLayerIds)
      ..removeAll(pruneResult.deletedGroupIds);

    emit(
      state.copyWith(
        shapes: prunedShapes,
        selectedShapeIds: newSelection,
        expandedLayerIds: cleanedExpanded,
      ),
    );
    _pushUndoState(prunedShapes);
  }

  void _onShapeUpdated(
    ShapeUpdated event,
    Emitter<CanvasState> emit,
  ) {
    if (!state.shapes.containsKey(event.shape.id)) return;
    VioLogger.debug('Updating shape: ${event.shape.id}');

    final newShapes = Map<String, Shape>.from(state.shapes);
    newShapes[event.shape.id] = event.shape;
    _notifyRepositoryShapeUpdated(event.shape);
    emit(state.copyWith(shapes: newShapes));
    _pushUndoState(newShapes);
  }

  void _onShapeSelected(
    ShapeSelected event,
    Emitter<CanvasState> emit,
  ) {
    if (!state.shapes.containsKey(event.shapeId)) return;

    List<String> newSelection;
    if (event.addToSelection) {
      // Toggle selection if already selected
      if (state.selectedShapeIds.contains(event.shapeId)) {
        newSelection =
            state.selectedShapeIds.where((id) => id != event.shapeId).toList();
      } else {
        newSelection = [...state.selectedShapeIds, event.shapeId];
      }
    } else {
      // Replace selection
      newSelection = [event.shapeId];
    }

    // Auto-expand parent layers to reveal the selected shape
    final expandedIds = _expandAncestorsForShapes(newSelection);

    emit(
      state.copyWith(
        selectedShapeIds: newSelection,
        expandedLayerIds: expandedIds,
      ),
    );
  }

  void _onShapesSelected(
    ShapesSelected event,
    Emitter<CanvasState> emit,
  ) {
    // Auto-expand parent layers to reveal the selected shapes
    final expandedIds = _expandAncestorsForShapes(event.shapeIds);

    emit(
      state.copyWith(
        selectedShapeIds: event.shapeIds,
        expandedLayerIds: expandedIds,
      ),
    );
  }

  // ============================================================================
  // Layer Panel Event Handlers
  // ============================================================================

  void _onLayerExpanded(
    LayerExpanded event,
    Emitter<CanvasState> emit,
  ) {
    final newExpanded = Set<String>.from(state.expandedLayerIds)
      ..add(event.layerId);
    emit(state.copyWith(expandedLayerIds: newExpanded));
  }

  void _onLayerCollapsed(
    LayerCollapsed event,
    Emitter<CanvasState> emit,
  ) {
    final newExpanded = Set<String>.from(state.expandedLayerIds)
      ..remove(event.layerId);
    emit(state.copyWith(expandedLayerIds: newExpanded));
  }

  void _onLayerHovered(
    LayerHovered event,
    Emitter<CanvasState> emit,
  ) {
    if (event.layerId == null) {
      emit(state.copyWith(clearHoveredLayerId: true));
    } else {
      emit(state.copyWith(hoveredLayerId: event.layerId));
    }
  }

  void _onShapeVisibilityToggled(
    ShapeVisibilityToggled event,
    Emitter<CanvasState> emit,
  ) {
    final shape = state.shapes[event.shapeId];
    if (shape == null) return;

    final updatedShape = shape.copyWith(hidden: !shape.hidden);
    final newShapes = Map<String, Shape>.from(state.shapes);
    newShapes[event.shapeId] = updatedShape;
    _notifyRepositoryShapeUpdated(updatedShape);
    emit(state.copyWith(shapes: newShapes));
    _pushUndoState(newShapes);
  }

  void _onShapeLockToggled(
    ShapeLockToggled event,
    Emitter<CanvasState> emit,
  ) {
    final shape = state.shapes[event.shapeId];
    if (shape == null) return;

    final updatedShape = shape.copyWith(blocked: !shape.blocked);
    final newShapes = Map<String, Shape>.from(state.shapes);
    newShapes[event.shapeId] = updatedShape;
    _notifyRepositoryShapeUpdated(updatedShape);
    emit(state.copyWith(shapes: newShapes));
    _pushUndoState(newShapes);
  }

  void _onShapeRenamed(
    ShapeRenamed event,
    Emitter<CanvasState> emit,
  ) {
    final shape = state.shapes[event.shapeId];
    if (shape == null) return;

    final updatedShape = shape.copyWith(name: event.newName);
    final newShapes = Map<String, Shape>.from(state.shapes);
    newShapes[event.shapeId] = updatedShape;
    emit(state.copyWith(shapes: newShapes));
  }

  void _onCanvasPointerExited(
    CanvasPointerExited event,
    Emitter<CanvasState> emit,
  ) {
    emit(
      state.copyWith(
        clearHoveredShapeId: true,
        clearHoveredCornerIndex: true,
      ),
    );
  }

  /// Expands all ancestor layers for the given shape IDs
  /// Returns the updated set of expanded layer IDs
  Set<String> _expandAncestorsForShapes(List<String> shapeIds) {
    final expanded = Set<String>.from(state.expandedLayerIds);

    for (final shapeId in shapeIds) {
      final shape = state.shapes[shapeId];
      if (shape == null) continue;

      // Walk up the parent chain (group parentId, then frameId) and expand.
      String? parentId = shape.parentId ?? shape.frameId;
      while (parentId != null) {
        final parent = state.shapes[parentId];
        if (parent == null) break;
        expanded.add(parentId);
        parentId = parent.parentId ?? parent.frameId;
      }
    }

    return expanded;
  }

  _PruneEmptyGroupsResult _pruneEmptyGroups(Map<String, Shape> shapes) {
    final nextShapes = Map<String, Shape>.from(shapes);

    // Count direct children per parentId.
    final childCounts = <String, int>{};
    for (final shape in nextShapes.values) {
      final parentId = shape.parentId;
      if (parentId == null) continue;
      childCounts[parentId] = (childCounts[parentId] ?? 0) + 1;
    }

    final deleted = <String>{};

    while (true) {
      final emptyGroupIds = <String>[];
      for (final entry in nextShapes.entries) {
        final shape = entry.value;
        if (shape is! GroupShape) continue;
        final count = childCounts[entry.key] ?? 0;
        if (count == 0) {
          emptyGroupIds.add(entry.key);
        }
      }

      if (emptyGroupIds.isEmpty) break;

      for (final groupId in emptyGroupIds) {
        final group = nextShapes[groupId];
        if (group is! GroupShape) continue;

        nextShapes.remove(groupId);
        deleted.add(groupId);

        // If this group was itself a child, decrement the parent's count so
        // now-empty parents are pruned too.
        final parentId = group.parentId;
        if (parentId != null) {
          final current = childCounts[parentId] ?? 0;
          if (current > 0) {
            childCounts[parentId] = current - 1;
          }
        }

        childCounts.remove(groupId);
      }
    }

    return _PruneEmptyGroupsResult(
      shapes: nextShapes,
      deletedGroupIds: deleted,
    );
  }

  // ============================================================================
  // Z-order Helpers
  // ============================================================================

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

  void _onBringToFrontSelected(
    BringToFrontSelected event,
    Emitter<CanvasState> emit,
  ) {
    if (state.selectedShapeIds.isEmpty) return;

    final reordered = _reorderSelectionInSiblings(
      shapes: state.shapes,
      selectedIds: state.selectedShapeIds,
      toFront: true,
    );

    if (identical(reordered, state.shapes)) return;

    // Notify repository for shapes that changed sortOrder.
    for (final entry in reordered.entries) {
      final prev = state.shapes[entry.key];
      final next = entry.value;
      if (prev != null && prev.sortOrder != next.sortOrder) {
        _notifyRepositoryShapeUpdated(next);
      }
    }

    emit(state.copyWith(shapes: reordered));
    _pushUndoState(reordered);
  }

  void _onSendToBackSelected(
    SendToBackSelected event,
    Emitter<CanvasState> emit,
  ) {
    if (state.selectedShapeIds.isEmpty) return;

    final reordered = _reorderSelectionInSiblings(
      shapes: state.shapes,
      selectedIds: state.selectedShapeIds,
      toFront: false,
    );

    if (identical(reordered, state.shapes)) return;

    for (final entry in reordered.entries) {
      final prev = state.shapes[entry.key];
      final next = entry.value;
      if (prev != null && prev.sortOrder != next.sortOrder) {
        _notifyRepositoryShapeUpdated(next);
      }
    }

    emit(state.copyWith(shapes: reordered));
    _pushUndoState(reordered);
  }

  void _onUngroupSelected(
    UngroupSelected event,
    Emitter<CanvasState> emit,
  ) {
    if (state.selectedShapeIds.isEmpty) return;

    final shapesById = Map<String, Shape>.from(state.shapes);
    final selectedSet = state.selectedShapeIds.toSet();

    final selectedGroups = state.selectedShapeIds
        .map((id) => shapesById[id])
        .whereType<GroupShape>()
        .where((g) => !g.blocked)
        .toList(growable: false);

    if (selectedGroups.isEmpty) return;

    int compareZ(Shape a, Shape b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      if (byOrder != 0) return byOrder;
      return a.id.compareTo(b.id);
    }

    final newSelection = <String>[];

    // Process ungroup per destination scope so we can insert children where the
    // group used to be.
    final groupsByScope = <String?, List<GroupShape>>{};
    for (final group in selectedGroups) {
      final scope = _effectiveContainerIdFor(
        shapes: shapesById,
        parentId: group.parentId,
        frameId: group.frameId,
      );
      groupsByScope.putIfAbsent(scope, () => []).add(group);
    }

    for (final entry in groupsByScope.entries) {
      final scope = entry.key;
      final scopeGroups = entry.value..sort(compareZ);

      // Build current siblings list in this scope.
      final siblings = <Shape>[];
      for (final shape in shapesById.values) {
        final shapeScope = _effectiveContainerIdFor(
          shapes: shapesById,
          parentId: shape.parentId,
          frameId: shape.frameId,
        );
        if (shapeScope == scope) {
          siblings.add(shape);
        }
      }
      siblings.sort(compareZ);

      for (final group in scopeGroups) {
        final groupIndex = siblings.indexWhere((s) => s.id == group.id);
        if (groupIndex < 0) continue;

        // Collect direct children of this group.
        final children = shapesById.values
            .where((s) => s.parentId == group.id)
            .toList(growable: false)
          ..sort(compareZ);

        // Reparent direct children up one level.
        for (final child in children) {
          shapesById[child.id] = child.copyWith(parentId: group.parentId);
          _notifyRepositoryShapeUpdated(shapesById[child.id]!);
        }

        // Remove the group itself.
        shapesById.remove(group.id);
        _notifyRepositoryShapeDeleted(group.id);

        // Replace the group in the siblings list with its children.
        siblings.removeAt(groupIndex);
        siblings.insertAll(groupIndex, children);

        // Select children after ungroup.
        for (final child in children) {
          newSelection.add(child.id);
        }
      }

      // Normalize sort order in this scope after modifications.
      for (var i = 0; i < siblings.length; i++) {
        final shape = siblings[i];
        final updated = shapesById[shape.id];
        if (updated != null && updated.sortOrder != i) {
          shapesById[shape.id] = updated.copyWith(sortOrder: i);
          _notifyRepositoryShapeUpdated(shapesById[shape.id]!);
        }
      }
    }

    // Keep any non-group selection as well.
    for (final id in selectedSet) {
      final shape = state.shapes[id];
      if (shape is GroupShape) continue;
      if (shapesById.containsKey(id)) {
        newSelection.add(id);
      }
    }

    final cleanedSelection = newSelection.toSet().toList(growable: false);

    emit(
      state.copyWith(
        shapes: shapesById,
        selectedShapeIds: cleanedSelection,
      ),
    );
    _pushUndoState(shapesById);
  }

  /// Detect snap points for current drag operation
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

  /// Convert screen coordinates to canvas coordinates
  Offset _screenToCanvas(Offset screenPoint) {
    return Offset(
      (screenPoint.dx - state.viewportOffset.dx) / state.zoom,
      (screenPoint.dy - state.viewportOffset.dy) / state.zoom,
    );
  }

  /// Convert canvas coordinates to screen coordinates
  Offset _canvasToScreen(Offset canvasPoint) {
    return Offset(
      canvasPoint.dx * state.zoom + state.viewportOffset.dx,
      canvasPoint.dy * state.zoom + state.viewportOffset.dy,
    );
  }

  // ============================================================================
  // Handle Hit Testing & Interaction Helpers
  // ============================================================================

  /// Handle size in screen pixels
  static const double _handleSize = 8.0;

  /// Rotation handle offset in canvas coordinates
  static const double _rotationHandleOffset = 24.0;

  /// Corner radius handle size in screen pixels
  static const double _cornerRadiusHandleSize = 10.0;

  /// Hit test for resize/rotate handles
  HandleInfo? _hitTestHandle(Offset screenPoint) {
    if (state.selectedShapes.any((s) => s.blocked)) return null;

    final bounds = state.selectionRect;
    if (bounds == null) return null;

    final isSingleTextSelection = state.selectedShapes.length == 1 &&
        state.selectedShapes.first is TextShape;

    bool isTextHandle(HandlePosition position) {
      return position == HandlePosition.rotation ||
          position == HandlePosition.topLeft ||
          position == HandlePosition.topRight ||
          position == HandlePosition.bottomLeft ||
          position == HandlePosition.bottomRight;
    }

    final handlePositions = _getHandlePositions(bounds);
    for (final entry in handlePositions.entries) {
      if (isSingleTextSelection && !isTextHandle(entry.key)) {
        continue;
      }
      final screenHandlePos = _canvasToScreen(entry.value);
      final handleInfo = HandleInfo(
        position: entry.key,
        center: screenHandlePos,
        size: _handleSize,
      );
      // Use larger hit area for easier interaction
      if (handleInfo.containsPoint(screenPoint)) {
        return handleInfo;
      }
    }
    return null;
  }

  /// Get handle positions in canvas coordinates
  Map<HandlePosition, Offset> _getHandlePositions(Rect bounds) {
    final centerX = bounds.center.dx;
    final centerY = bounds.center.dy;

    return {
      HandlePosition.topLeft: Offset(bounds.left, bounds.top),
      HandlePosition.topCenter: Offset(centerX, bounds.top),
      HandlePosition.topRight: Offset(bounds.right, bounds.top),
      HandlePosition.middleLeft: Offset(bounds.left, centerY),
      HandlePosition.middleRight: Offset(bounds.right, centerY),
      HandlePosition.bottomLeft: Offset(bounds.left, bounds.bottom),
      HandlePosition.bottomCenter: Offset(centerX, bounds.bottom),
      HandlePosition.bottomRight: Offset(bounds.right, bounds.bottom),
      HandlePosition.rotation:
          Offset(centerX, bounds.top - _rotationHandleOffset),
    };
  }

  /// Hit test for corner radius handles
  _CornerRadiusHit? _hitTestCornerRadiusHandle(Offset screenPoint) {
    if (state.selectedShapes.length != 1) return null;

    final shape = state.selectedShapes.first;
    if (shape.blocked) return null;
    if (shape is! RectangleShape) return null;

    final positions = _getCornerRadiusHandlePositions(shape);
    for (var i = 0; i < positions.length; i++) {
      final screenHandlePos = _canvasToScreen(positions[i]);
      final distance = (screenPoint - screenHandlePos).distance;
      if (distance <= _cornerRadiusHandleSize) {
        return _CornerRadiusHit(index: i, position: positions[i]);
      }
    }
    return null;
  }

  /// Get corner radius handle positions in canvas coordinates
  List<Offset> _getCornerRadiusHandlePositions(RectangleShape rect) {
    final bounds = rect.bounds;

    const minInset = 8.0;
    double insetFor(double radius) => math.max(minInset, radius);

    return [
      rect.transformPoint(
        Offset(bounds.left + insetFor(rect.r1), bounds.top + insetFor(rect.r1)),
      ),
      rect.transformPoint(
        Offset(
          bounds.right - insetFor(rect.r2),
          bounds.top + insetFor(rect.r2),
        ),
      ),
      rect.transformPoint(
        Offset(
          bounds.right - insetFor(rect.r3),
          bounds.bottom - insetFor(rect.r3),
        ),
      ),
      rect.transformPoint(
        Offset(
          bounds.left + insetFor(rect.r4),
          bounds.bottom - insetFor(rect.r4),
        ),
      ),
    ];
  }

  /// Get the resize origin (anchor point) based on handle position
  Offset? _getResizeOrigin(HandlePosition handle, Rect? bounds) {
    if (bounds == null) return null;

    switch (handle) {
      case HandlePosition.topLeft:
        return Offset(bounds.right, bounds.bottom);
      case HandlePosition.topCenter:
        return Offset(bounds.center.dx, bounds.bottom);
      case HandlePosition.topRight:
        return Offset(bounds.left, bounds.bottom);
      case HandlePosition.middleLeft:
        return Offset(bounds.right, bounds.center.dy);
      case HandlePosition.middleRight:
        return Offset(bounds.left, bounds.center.dy);
      case HandlePosition.bottomLeft:
        return Offset(bounds.right, bounds.top);
      case HandlePosition.bottomCenter:
        return Offset(bounds.center.dx, bounds.top);
      case HandlePosition.bottomRight:
        return Offset(bounds.left, bounds.top);
      case HandlePosition.rotation:
        return bounds.center;
    }
  }

  /// Calculate new shape dimensions during resize
  Map<String, Shape> _calculateResize(
    Offset currentPointer,
    HandlePosition handle,
    Offset origin,
    Rect originalBounds,
  ) {
    final newShapes = Map<String, Shape>.from(state.shapes);
    final originalShapes = state.originalShapes;

    final originalWidth = originalBounds.width;
    final originalHeight = originalBounds.height;

    // Calculate new bounds based on handle being dragged
    double newLeft = originalBounds.left;
    double newTop = originalBounds.top;
    double newRight = originalBounds.right;
    double newBottom = originalBounds.bottom;

    // Update the appropriate edges based on handle position
    switch (handle) {
      case HandlePosition.topLeft:
        newLeft = currentPointer.dx;
        newTop = currentPointer.dy;
        break;
      case HandlePosition.topCenter:
        newTop = currentPointer.dy;
        break;
      case HandlePosition.topRight:
        newRight = currentPointer.dx;
        newTop = currentPointer.dy;
        break;
      case HandlePosition.middleLeft:
        newLeft = currentPointer.dx;
        break;
      case HandlePosition.middleRight:
        newRight = currentPointer.dx;
        break;
      case HandlePosition.bottomLeft:
        newLeft = currentPointer.dx;
        newBottom = currentPointer.dy;
        break;
      case HandlePosition.bottomCenter:
        newBottom = currentPointer.dy;
        break;
      case HandlePosition.bottomRight:
        newRight = currentPointer.dx;
        newBottom = currentPointer.dy;
        break;
      case HandlePosition.rotation:
        return newShapes; // No resize for rotation handle
    }

    // Handle flipping (when user drags past the origin)
    final flipX = newLeft > newRight;
    final flipY = newTop > newBottom;
    if (flipX) {
      final temp = newLeft;
      newLeft = newRight;
      newRight = temp;
    }
    if (flipY) {
      final temp = newTop;
      newTop = newBottom;
      newBottom = temp;
    }

    // Calculate new dimensions
    final newWidth = (newRight - newLeft).clamp(1.0, double.infinity);
    final newHeight = (newBottom - newTop).clamp(1.0, double.infinity);

    // Apply resize to each selected shape
    for (final shapeId in state.selectedShapeIds) {
      // Use ORIGINAL shape bounds for calculating relative position
      final originalShape = originalShapes?[shapeId];
      final currentShape = newShapes[shapeId];
      if (originalShape == null || currentShape == null) continue;
      if (originalShape.blocked) continue;

      // Calculate shape's relative position within original selection bounds
      // using the ORIGINAL shape bounds (not current)
      final originalShapeBounds = originalShape.bounds;
      final relLeft =
          (originalShapeBounds.left - originalBounds.left) / originalWidth;
      final relTop =
          (originalShapeBounds.top - originalBounds.top) / originalHeight;
      final relWidth = originalShapeBounds.width / originalWidth;
      final relHeight = originalShapeBounds.height / originalHeight;

      // Calculate new position and size maintaining relative proportions
      final shapeNewWidth = (relWidth * newWidth).clamp(1.0, double.infinity);
      final shapeNewHeight =
          (relHeight * newHeight).clamp(1.0, double.infinity);
      final shapeNewX = newLeft + relLeft * newWidth;
      final shapeNewY = newTop + relTop * newHeight;

      // Apply to shape based on type (use originalShape as base for copyWith)
      if (originalShape is RectangleShape) {
        newShapes[shapeId] = originalShape.copyWith(
          x: shapeNewX,
          y: shapeNewY,
          rectWidth: shapeNewWidth,
          rectHeight: shapeNewHeight,
        );
      } else if (originalShape is EllipseShape) {
        newShapes[shapeId] = originalShape.copyWith(
          x: shapeNewX,
          y: shapeNewY,
          ellipseWidth: shapeNewWidth,
          ellipseHeight: shapeNewHeight,
        );
      } else if (originalShape is FrameShape) {
        newShapes[shapeId] = originalShape.copyWith(
          x: shapeNewX,
          y: shapeNewY,
          frameWidth: shapeNewWidth,
          frameHeight: shapeNewHeight,
        );
      } else if (originalShape is TextShape) {
        newShapes[shapeId] = originalShape.copyWith(
          x: shapeNewX,
          y: shapeNewY,
          textWidth: shapeNewWidth,
          textHeight: shapeNewHeight,
        );
      }
    }

    return newShapes;
  }

  /// Calculate rotation angle during rotation interaction
  double _calculateRotationAngle(Offset currentPointer, Offset center) {
    final dx = currentPointer.dx - center.dx;
    final dy = currentPointer.dy - center.dy;
    return math.atan2(dx, -dy) * 180 / math.pi;
  }

  /// Calculate corner radius based on handle drag
  double _calculateCornerRadius(
    Offset currentPointer,
    int cornerIndex,
    RectangleShape shape,
  ) {
    final bounds = shape.bounds;

    // Convert pointer to local coordinates so radius works with transforms.
    final localPointer = shape.inverseTransformPoint(currentPointer);

    // Calculate distance from corner to current pointer position
    Offset corner;
    switch (cornerIndex) {
      case 0: // Top-left
        corner = Offset(bounds.left, bounds.top);
        break;
      case 1: // Top-right
        corner = Offset(bounds.right, bounds.top);
        break;
      case 2: // Bottom-right
        corner = Offset(bounds.right, bounds.bottom);
        break;
      case 3: // Bottom-left
        corner = Offset(bounds.left, bounds.bottom);
        break;
      default:
        corner = bounds.topLeft;
    }

    // Calculate diagonal distance from corner to pointer
    final dx = (localPointer.dx - corner.dx).abs();
    final dy = (localPointer.dy - corner.dy).abs();

    // Use the smaller inset to match the handle behavior (inset r,r).
    final radius = math.min(dx, dy);

    // Clamp to reasonable values (max is half the smaller dimension)
    final maxRadius = math.min(bounds.width, bounds.height) / 2;
    return radius.clamp(0.0, maxRadius);
  }

  // ============================================================================
  // Clipboard Handlers
  // ============================================================================

  void _onShapesRemoved(
    ShapesRemoved event,
    Emitter<CanvasState> emit,
  ) {
    if (event.shapeIds.isEmpty) return;

    final newShapes = Map<String, Shape>.from(state.shapes);
    for (final id in event.shapeIds) {
      newShapes.remove(id);
    }

    final pruneResult = _pruneEmptyGroups(newShapes);
    final prunedShapes = pruneResult.shapes;
    if (pruneResult.deletedGroupIds.isNotEmpty) {
      for (final id in pruneResult.deletedGroupIds) {
        _notifyRepositoryShapeDeleted(id);
      }
    }

    // Also remove from selection
    final removedSet = event.shapeIds.toSet();
    final removedAll = <String>{...removedSet, ...pruneResult.deletedGroupIds};
    final newSelection =
        state.selectedShapeIds.where((id) => !removedAll.contains(id)).toList();

    final cleanedExpanded = Set<String>.from(state.expandedLayerIds)
      ..removeAll(pruneResult.deletedGroupIds);

    emit(
      state.copyWith(
        shapes: prunedShapes,
        selectedShapeIds: newSelection,
        expandedLayerIds: cleanedExpanded,
        syncStatus: state.isConnected ? SyncStatus.pending : state.syncStatus,
      ),
    );
    _pushUndoState(prunedShapes);
  }

  void _onCopySelected(
    CopySelected event,
    Emitter<CanvasState> emit,
  ) {
    if (state.selectedShapeIds.isEmpty) return;

    // Copy selected shapes to clipboard
    final shapesToCopy = state.selectedShapes;
    emit(state.copyWith(clipboardShapes: shapesToCopy));

    // Copy doesn't alter shapes, so no undo state.
  }

  void _onCutSelected(
    CutSelected event,
    Emitter<CanvasState> emit,
  ) {
    if (state.selectedShapeIds.isEmpty) return;

    final cuttable = <Shape>[];
    final remainingSelected = <String>[];

    for (final id in state.selectedShapeIds) {
      final shape = state.shapes[id];
      if (shape == null) continue;
      if (shape.blocked) {
        remainingSelected.add(id);
        continue;
      }
      cuttable.add(shape);
    }

    if (cuttable.isEmpty) return;

    // Copy to clipboard first
    final shapesToCopy = List<Shape>.unmodifiable(cuttable);

    // Then remove from canvas
    final newShapes = Map<String, Shape>.from(state.shapes);
    for (final shape in cuttable) {
      newShapes.remove(shape.id);
      _notifyRepositoryShapeDeleted(shape.id);
    }

    final pruneResult = _pruneEmptyGroups(newShapes);
    final prunedShapes = pruneResult.shapes;
    if (pruneResult.deletedGroupIds.isNotEmpty) {
      for (final id in pruneResult.deletedGroupIds) {
        _notifyRepositoryShapeDeleted(id);
      }
    }

    final cleanedExpanded = Set<String>.from(state.expandedLayerIds)
      ..removeAll(pruneResult.deletedGroupIds);
    final cleanedSelection = remainingSelected
        .where((id) => !pruneResult.deletedGroupIds.contains(id))
        .toList(growable: false);

    emit(
      state.copyWith(
        clipboardShapes: shapesToCopy,
        shapes: prunedShapes,
        selectedShapeIds: cleanedSelection,
        expandedLayerIds: cleanedExpanded,
        syncStatus: state.isConnected ? SyncStatus.pending : state.syncStatus,
      ),
    );
    _pushUndoState(prunedShapes);
  }

  void _onPasteShapes(
    PasteShapes event,
    Emitter<CanvasState> emit,
  ) {
    if (state.clipboardShapes.isEmpty) return;

    // Duplicate shapes with new IDs and offset position
    const pasteOffset = 10.0; // Offset like Penpot
    final newShapes = Map<String, Shape>.from(state.shapes);
    final newIds = <String>[];

    final nextSortOrders = <String?, int>{};
    int nextForScope({required String? parentId, required String? frameId}) {
      final key = _effectiveContainerIdFor(
        shapes: newShapes,
        parentId: parentId,
        frameId: frameId,
      );
      final existing = nextSortOrders[key];
      if (existing != null) {
        nextSortOrders[key] = existing + 1;
        return existing;
      }
      final initial = _nextSortOrderForNewShape(
        shapes: newShapes,
        parentId: parentId,
        frameId: frameId,
      );
      nextSortOrders[key] = initial + 1;
      return initial;
    }

    for (final shape in state.clipboardShapes) {
      final newId = _uuid.v4();
      final duplicated = shape.duplicate(
        newId: newId,
        offsetX: pasteOffset,
        offsetY: pasteOffset,
      );

      final z = nextForScope(
        parentId: duplicated.parentId,
        frameId: duplicated.frameId,
      );
      newShapes[newId] = duplicated.copyWith(sortOrder: z);
      newIds.add(newId);
    }

    // Select the pasted shapes
    emit(
      state.copyWith(
        shapes: newShapes,
        selectedShapeIds: newIds,
      ),
    );
    _pushUndoState(newShapes);
  }

  void _onDuplicateSelected(
    DuplicateSelected event,
    Emitter<CanvasState> emit,
  ) {
    if (state.selectedShapeIds.isEmpty) return;

    // Duplicate selected shapes with offset
    const duplicateOffset = 10.0;
    final newShapes = Map<String, Shape>.from(state.shapes);
    final newIds = <String>[];

    final nextSortOrders = <String?, int>{};
    int nextForScope({required String? parentId, required String? frameId}) {
      final key = _effectiveContainerIdFor(
        shapes: newShapes,
        parentId: parentId,
        frameId: frameId,
      );
      final existing = nextSortOrders[key];
      if (existing != null) {
        nextSortOrders[key] = existing + 1;
        return existing;
      }
      final initial = _nextSortOrderForNewShape(
        shapes: newShapes,
        parentId: parentId,
        frameId: frameId,
      );
      nextSortOrders[key] = initial + 1;
      return initial;
    }

    for (final shape in state.selectedShapes) {
      if (shape.blocked) continue;
      final newId = _uuid.v4();
      final duplicated = shape.duplicate(
        newId: newId,
        offsetX: duplicateOffset,
        offsetY: duplicateOffset,
      );

      final z = nextForScope(
        parentId: duplicated.parentId,
        frameId: duplicated.frameId,
      );
      newShapes[newId] = duplicated.copyWith(sortOrder: z);
      newIds.add(newId);
    }

    if (newIds.isEmpty) return;

    // Select the duplicated shapes
    emit(
      state.copyWith(
        shapes: newShapes,
        selectedShapeIds: newIds,
      ),
    );
    _pushUndoState(newShapes);
  }

  void _onDeleteSelected(
    DeleteSelected event,
    Emitter<CanvasState> emit,
  ) {
    if (state.selectedShapeIds.isEmpty) return;

    final newShapes = Map<String, Shape>.from(state.shapes);
    final remainingSelected = <String>[];
    for (final id in state.selectedShapeIds) {
      final shape = state.shapes[id];
      if (shape == null) continue;
      if (shape.blocked) {
        remainingSelected.add(id);
        continue;
      }
      newShapes.remove(id);
      _notifyRepositoryShapeDeleted(id);
    }

    // If everything selected was locked, do nothing.
    if (newShapes.length == state.shapes.length) {
      return;
    }

    final pruneResult = _pruneEmptyGroups(newShapes);
    final prunedShapes = pruneResult.shapes;
    if (pruneResult.deletedGroupIds.isNotEmpty) {
      for (final id in pruneResult.deletedGroupIds) {
        _notifyRepositoryShapeDeleted(id);
      }
    }

    final cleanedExpanded = Set<String>.from(state.expandedLayerIds)
      ..removeAll(pruneResult.deletedGroupIds);
    final cleanedSelection = remainingSelected
        .where((id) => !pruneResult.deletedGroupIds.contains(id))
        .toList(growable: false);

    emit(
      state.copyWith(
        shapes: prunedShapes,
        selectedShapeIds: cleanedSelection,
        expandedLayerIds: cleanedExpanded,
        syncStatus: state.isConnected ? SyncStatus.pending : state.syncStatus,
      ),
    );
    _pushUndoState(prunedShapes);
  }

  // ============================================================================
  // Sync Event Handlers
  // ============================================================================

  /// Subscription for repository sync status changes
  StreamSubscription<SyncStatus>? _syncStatusSubscription;

  /// Track a shape operation for syncing to repository
  void _notifyRepositoryShapeAdded(Shape shape) {
    _repository?.addShape(shape);
  }

  void _notifyRepositoryShapeUpdated(Shape shape) {
    _repository?.updateShape(shape);
  }

  void _notifyRepositoryShapeDeleted(String shapeId) {
    _repository?.deleteShape(shapeId);
  }

  Future<void> _onCanvasLoadRequested(
    CanvasLoadRequested event,
    Emitter<CanvasState> emit,
  ) async {
    if (_repository == null) {
      VioLogger.warning('GrpcCanvasRepository not available for sync');
      return;
    }

    emit(
      state.copyWith(
        syncStatus: SyncStatus.loading,
        projectId: event.projectId,
        branchId: event.branchId,
        clearSyncError: true,
      ),
    );

    try {
      // Initialize the repository which loads from server
      await _repository.initialize(
        projectId: event.projectId,
        branchId: event.branchId,
      );

      // Convert repository shapes to map
      final shapes = <String, Shape>{};
      for (final shape in _repository.shapes) {
        shapes[shape.id] = shape;
      }

      add(
        CanvasLoadSucceeded(
          shapes: shapes,
          serverVersion: 0, // Repository tracks version internally
        ),
      );

      // Subscribe to sync status changes
      _syncStatusSubscription?.cancel();
      _syncStatusSubscription = _repository.syncStatusStream.listen((status) {
        // Map repository SyncStatus to bloc SyncStatus
        final blocStatus = _mapSyncStatus(status);
        if (state.syncStatus != blocStatus) {
          // Emit state change through event to stay reactive
          if (status == SyncStatus.synced) {
            add(const CanvasSyncSucceeded(serverVersion: 0));
          } else if (status == SyncStatus.error) {
            add(const CanvasSyncFailed('Sync error'));
          }
        }
      });
    } catch (e) {
      add(CanvasLoadFailed(e.toString()));
    }
  }

  /// Map repository SyncStatus to canvas state SyncStatus
  SyncStatus _mapSyncStatus(SyncStatus repoStatus) {
    // They use the same enum now, but this allows for future differences
    return repoStatus;
  }

  void _onCanvasLoadSucceeded(
    CanvasLoadSucceeded event,
    Emitter<CanvasState> emit,
  ) {
    // Clear undo stack and start fresh with server state
    _undoStack.clear();
    _redoStack.clear();
    _undoStack.add(Map.from(event.shapes));

    emit(
      state.copyWith(
        shapes: event.shapes,
        serverVersion: event.serverVersion,
        syncStatus: SyncStatus.synced,
        selectedShapeIds: const [],
        clearSyncError: true,
      ),
    );

    VioLogger.info('Canvas loaded with ${event.shapes.length} shapes');
  }

  void _onCanvasLoadFailed(
    CanvasLoadFailed event,
    Emitter<CanvasState> emit,
  ) {
    emit(
      state.copyWith(
        syncStatus: SyncStatus.error,
        syncError: event.error,
      ),
    );
    VioLogger.error('Canvas load failed: ${event.error}');
  }

  Future<void> _onCanvasSyncRequested(
    CanvasSyncRequested event,
    Emitter<CanvasState> emit,
  ) async {
    if (_repository == null || !state.isConnected) {
      return;
    }

    emit(state.copyWith(syncStatus: SyncStatus.syncing));

    try {
      await _repository.sync();
      // Sync status will be updated via stream subscription
    } catch (e) {
      add(CanvasSyncFailed(e.toString()));
    }
  }

  void _onCanvasSyncSucceeded(
    CanvasSyncSucceeded event,
    Emitter<CanvasState> emit,
  ) {
    emit(
      state.copyWith(
        serverVersion: event.serverVersion,
        syncStatus: SyncStatus.synced,
        clearSyncError: true,
      ),
    );
    VioLogger.debug('Canvas synced');
  }

  void _onCanvasSyncFailed(
    CanvasSyncFailed event,
    Emitter<CanvasState> emit,
  ) {
    emit(
      state.copyWith(
        syncStatus: SyncStatus.error,
        syncError: event.error,
      ),
    );
    VioLogger.error('Canvas sync failed: ${event.error}');
  }

  @override
  Future<void> close() {
    _syncStatusSubscription?.cancel();
    return super.close();
  }
}
