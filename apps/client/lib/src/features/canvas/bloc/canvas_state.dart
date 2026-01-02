part of 'canvas_bloc.dart';

/// Current interaction mode for the canvas
enum InteractionMode {
  /// No active interaction
  idle,

  /// User is panning the viewport
  panning,

  /// User is dragging to select or create
  dragging,

  /// User is moving selected shapes
  movingShapes,

  /// User is drawing a new shape
  drawing,

  /// User is resizing a shape
  resizing,

  /// User is rotating a shape
  rotating,
}

// Note: SyncStatus is imported from '../../../core/repositories/canvas_repository.dart'
// via the core.dart barrel file

/// Represents the complete state of the canvas
class CanvasState extends Equatable {
  const CanvasState({
    this.zoom = 1.0,
    this.viewportOffset = const Offset(0, 0),
    this.viewportSize = const Size(800, 600),
    this.interactionMode = InteractionMode.idle,
    this.dragStart,
    this.currentPointer,
    this.dragOffset,
    this.shapes = const {},
    this.selectedShapeIds = const [],
    this.hoveredShapeId,
    this.expandedLayerIds = const {},
    this.hoveredLayerId,
    this.snapLines = const [],
    this.snapPoints = const [],
    this.clipboardShapes = const [],
    this.syncStatus = SyncStatus.idle,
    this.serverVersion = 0,
    this.syncError,
    this.projectId,
    this.branchId,
  });

  /// Current zoom level (1.0 = 100%)
  final double zoom;

  /// Viewport offset (pan position) in screen coordinates
  final Offset viewportOffset;

  /// Viewport size in screen coordinates
  final Size viewportSize;

  /// Current interaction mode
  final InteractionMode interactionMode;

  /// Starting point of current drag operation (canvas coordinates)
  final Offset? dragStart;

  /// Current pointer position (canvas coordinates)
  final Offset? currentPointer;

  /// Current drag offset for moving shapes (performance optimization)
  /// Applied at render time instead of mutating shapes during drag
  final Offset? dragOffset;

  /// All shapes on the canvas, keyed by ID
  final Map<String, Shape> shapes;

  /// IDs of currently selected shapes
  final List<String> selectedShapeIds;

  /// ID of shape currently under the pointer (canvas)
  final String? hoveredShapeId;

  /// IDs of expanded layers in the layers panel (frames/groups)
  final Set<String> expandedLayerIds;

  /// ID of layer currently hovered in the layers panel
  final String? hoveredLayerId;

  /// Active snap lines to render (during drag)
  final List<SnapLine> snapLines;

  /// Active snap points to render (during drag)
  final List<SnapPoint> snapPoints;

  /// Shapes stored in clipboard for copy/paste operations
  final List<Shape> clipboardShapes;

  /// Current sync status with the server
  final SyncStatus syncStatus;

  /// Server version for conflict resolution
  final int serverVersion;

  /// Error message if sync failed
  final String? syncError;

  /// Current project ID (null if not connected)
  final String? projectId;

  /// Current branch ID (null if not connected)
  final String? branchId;

  /// Whether canvas is connected to a project/branch
  bool get isConnected => projectId != null && branchId != null;

  /// Whether there are pending changes to sync
  bool get hasPendingChanges => syncStatus == SyncStatus.pending;

  /// Get shapes as an ordered list (for rendering)
  List<Shape> get shapeList => shapes.values.toList();

  /// Get currently selected shapes
  List<Shape> get selectedShapes =>
      selectedShapeIds.map((id) => shapes[id]).whereType<Shape>().toList();

  /// Get the combined bounding rect of selected shapes (with drag offset applied)
  Rect? get selectionRect {
    if (selectedShapeIds.isEmpty) return null;

    double? minX, minY, maxX, maxY;

    for (final shapeId in selectedShapeIds) {
      final shape = shapes[shapeId];
      if (shape == null) continue;

      final bounds = shape.bounds;
      // Get transformed corners
      final corners = [
        shape.transformPoint(Offset(bounds.left, bounds.top)),
        shape.transformPoint(Offset(bounds.right, bounds.top)),
        shape.transformPoint(Offset(bounds.right, bounds.bottom)),
        shape.transformPoint(Offset(bounds.left, bounds.bottom)),
      ];

      for (final corner in corners) {
        minX = minX == null ? corner.dx : (corner.dx < minX ? corner.dx : minX);
        minY = minY == null ? corner.dy : (corner.dy < minY ? corner.dy : minY);
        maxX = maxX == null ? corner.dx : (corner.dx > maxX ? corner.dx : maxX);
        maxY = maxY == null ? corner.dy : (corner.dy > maxY ? corner.dy : maxY);
      }
    }

    if (minX == null || minY == null || maxX == null || maxY == null) {
      return null;
    }

    // Apply drag offset if dragging
    final offsetX = dragOffset?.dx ?? 0;
    final offsetY = dragOffset?.dy ?? 0;

    return Rect.fromLTWH(
      minX + offsetX,
      minY + offsetY,
      maxX - minX,
      maxY - minY,
    );
  }

  /// Get the visible rectangle in canvas coordinates
  Rect get visibleRect {
    final topLeft = screenToCanvas(const Size(0, 0));
    final bottomRight = screenToCanvas(viewportSize);
    return Rect.fromPoints(topLeft, bottomRight);
  }

  /// Convert screen coordinates to canvas coordinates
  Offset screenToCanvas(Size screenPoint) {
    return Offset(
      (screenPoint.width - viewportOffset.dx) / zoom,
      (screenPoint.height - viewportOffset.dy) / zoom,
    );
  }

  /// Convert canvas coordinates to screen coordinates
  Offset canvasToScreen(Offset canvasPoint) {
    return Offset(
      canvasPoint.dx * zoom + viewportOffset.dx,
      canvasPoint.dy * zoom + viewportOffset.dy,
    );
  }

  /// Get the transformation matrix for rendering
  Matrix2D get viewMatrix {
    // Scale the canvas, then translate in screen space (x' = x*zoom + offset)
    // Use T * S (translate then scale) so translation is not scaled.
    return Matrix2D.identity
        .translated(viewportOffset.dx, viewportOffset.dy)
        .scaled(zoom, zoom);
  }

  /// Whether there is an active selection
  bool get hasSelection => selectedShapeIds.isNotEmpty;

  /// Whether the canvas is in a dragging state
  bool get isDragging => interactionMode == InteractionMode.dragging;

  /// Get drag rectangle if currently doing marquee selection
  Rect? get dragRect {
    // Only show drag rect during marquee selection, not during shape movement
    if (interactionMode != InteractionMode.dragging) return null;
    if (dragStart == null || currentPointer == null) return null;
    return Rect.fromPoints(dragStart!, currentPointer!);
  }

  CanvasState copyWith({
    double? zoom,
    Offset? viewportOffset,
    Size? viewportSize,
    InteractionMode? interactionMode,
    Offset? dragStart,
    Offset? currentPointer,
    Offset? dragOffset,
    Map<String, Shape>? shapes,
    List<String>? selectedShapeIds,
    String? hoveredShapeId,
    Set<String>? expandedLayerIds,
    String? hoveredLayerId,
    List<SnapLine>? snapLines,
    List<SnapPoint>? snapPoints,
    List<Shape>? clipboardShapes,
    SyncStatus? syncStatus,
    int? serverVersion,
    String? syncError,
    String? projectId,
    String? branchId,
    bool clearDragStart = false,
    bool clearCurrentPointer = false,
    bool clearDragOffset = false,
    bool clearHoveredShapeId = false,
    bool clearHoveredLayerId = false,
    bool clearSnap = false,
    bool clearSyncError = false,
  }) {
    return CanvasState(
      zoom: zoom ?? this.zoom,
      viewportOffset: viewportOffset ?? this.viewportOffset,
      viewportSize: viewportSize ?? this.viewportSize,
      interactionMode: interactionMode ?? this.interactionMode,
      dragStart: clearDragStart ? null : (dragStart ?? this.dragStart),
      currentPointer:
          clearCurrentPointer ? null : (currentPointer ?? this.currentPointer),
      dragOffset: clearDragOffset ? null : (dragOffset ?? this.dragOffset),
      shapes: shapes ?? this.shapes,
      selectedShapeIds: selectedShapeIds ?? this.selectedShapeIds,
      hoveredShapeId:
          clearHoveredShapeId ? null : (hoveredShapeId ?? this.hoveredShapeId),
      expandedLayerIds: expandedLayerIds ?? this.expandedLayerIds,
      hoveredLayerId:
          clearHoveredLayerId ? null : (hoveredLayerId ?? this.hoveredLayerId),
      snapLines: clearSnap ? const [] : (snapLines ?? this.snapLines),
      snapPoints: clearSnap ? const [] : (snapPoints ?? this.snapPoints),
      clipboardShapes: clipboardShapes ?? this.clipboardShapes,
      syncStatus: syncStatus ?? this.syncStatus,
      serverVersion: serverVersion ?? this.serverVersion,
      syncError: clearSyncError ? null : (syncError ?? this.syncError),
      projectId: projectId ?? this.projectId,
      branchId: branchId ?? this.branchId,
    );
  }

  @override
  List<Object?> get props => [
        zoom,
        viewportOffset,
        viewportSize,
        interactionMode,
        dragStart,
        currentPointer,
        dragOffset,
        shapes,
        selectedShapeIds,
        hoveredShapeId,
        expandedLayerIds,
        hoveredLayerId,
        snapLines,
        snapPoints,
        clipboardShapes,
        syncStatus,
        serverVersion,
        syncError,
        projectId,
        branchId,
      ];
}
