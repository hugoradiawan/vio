part of 'canvas_bloc.dart';

const _deviceFrameIphone16ProSize = Size(402.0, 874.0);
const _deviceFrameIphone16Size = Size(393.0, 852.0);
const _deviceFrameSizeTolerance = 0.5;

bool _isSupportedDeviceFrameSize(double width, double height) {
  bool nearlyMatches(Size size) {
    return (width - size.width).abs() <= _deviceFrameSizeTolerance &&
        (height - size.height).abs() <= _deviceFrameSizeTolerance;
  }

  return nearlyMatches(_deviceFrameIphone16ProSize) ||
      nearlyMatches(_deviceFrameIphone16Size);
}

mixin _CanvasCommandsMixin on Bloc<CanvasEvent, CanvasState> {
  List<Map<String, Shape>> get _undoStack;
  List<Map<String, Shape>> get _redoStack;

  void _notifyRepositoryShapeAdded(Shape shape);
  void _notifyRepositoryShapeUpdated(Shape shape);
  void _notifyRepositoryShapeDeleted(String shapeId);

  void _pushUndoState(Map<String, Shape> shapes);
  _PruneEmptyGroupsResult _pruneEmptyGroups(Map<String, Shape> shapes);
  Set<String> _expandAncestorsForShapes(List<String> shapeIds);

  // Rust engine state (from _CanvasRustMixin)
  RustEngineService get _rustEngine;
  set _rustEngineLoaded(bool value);
  set _lastRustSyncedShapes(Map<String, Shape> value);

  String? _effectiveContainerIdFor({
    required Map<String, Shape> shapes,
    required String? parentId,
    required String? frameId,
  });

  int _nextSortOrderForNewShape({
    required Map<String, Shape> shapes,
    required String? parentId,
    required String? frameId,
  });

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

  void _onShapesReplaced(
    ShapesReplaced event,
    Emitter<CanvasState> emit,
  ) {
    _undoStack.clear();
    _redoStack.clear();
    _undoStack.add(Map.from(event.shapes));

    // Reset Rust engine so the next onChange triggers a fresh bulk load.
    _rustEngine.reset();
    _rustEngineLoaded = false;
    _lastRustSyncedShapes = const {};

    VioLogger.info(
      'CanvasBloc: Shapes replaced from branch switch: ${event.shapes.length} shapes',
    );

    emit(
      state.copyWith(
        shapes: event.shapes,
        selectedShapeIds: const [],
        expandedLayerIds: const {},
        interactionMode: InteractionMode.idle,
        clearDragStart: true,
        clearDragOffset: true,
        clearSnap: true,
        clearEditingTextShapeId: true,
      ),
    );
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

    // If a device-framed FrameShape is resized away from supported iPhone
    // device-frame dimensions, automatically disable the overlay.
    Shape updatedShape = event.shape;
    if (updatedShape is FrameShape && updatedShape.showDeviceFrame) {
      if (!_isSupportedDeviceFrameSize(
        updatedShape.frameWidth,
        updatedShape.frameHeight,
      )) {
        updatedShape = updatedShape.copyWith(showDeviceFrame: false);
      }
    }

    final newShapes = Map<String, Shape>.from(state.shapes);
    newShapes[updatedShape.id] = updatedShape;
    _notifyRepositoryShapeUpdated(updatedShape);
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
      if (state.selectedShapeIds.contains(event.shapeId)) {
        newSelection =
            state.selectedShapeIds.where((id) => id != event.shapeId).toList();
      } else {
        newSelection = [...state.selectedShapeIds, event.shapeId];
      }
    } else {
      newSelection = [event.shapeId];
    }

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
    final expandedIds = _expandAncestorsForShapes(event.shapeIds);

    emit(
      state.copyWith(
        selectedShapeIds: event.shapeIds,
        expandedLayerIds: expandedIds,
      ),
    );
  }

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
        clearSelectionCursorKind: true,
      ),
    );
  }

  void _onHoverCleared(
    HoverCleared event,
    Emitter<CanvasState> emit,
  ) {
    if (state.hoveredShapeId == null) return;
    emit(state.copyWith(clearHoveredShapeId: true));
  }

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

    final shapesToCopy = state.selectedShapes;
    emit(state.copyWith(clipboardShapes: shapesToCopy));
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

    final shapesToCopy = List<Shape>.unmodifiable(cuttable);

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

    const pasteOffset = 10.0;
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
      final duplicatedWithSortOrder = duplicated.copyWith(sortOrder: z);
      newShapes[newId] = duplicatedWithSortOrder;
      _notifyRepositoryShapeAdded(duplicatedWithSortOrder);
      newIds.add(newId);
    }

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
      final duplicatedWithSortOrder = duplicated.copyWith(sortOrder: z);
      newShapes[newId] = duplicatedWithSortOrder;
      _notifyRepositoryShapeAdded(duplicatedWithSortOrder);
      newIds.add(newId);
    }

    if (newIds.isEmpty) return;

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
}
