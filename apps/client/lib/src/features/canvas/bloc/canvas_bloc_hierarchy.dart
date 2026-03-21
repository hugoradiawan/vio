part of 'canvas_bloc.dart';

mixin _CanvasHierarchyMixin on Bloc<CanvasEvent, CanvasState> {
  void _notifyRepositoryShapeAdded(Shape shape);
  void _notifyRepositoryShapeUpdated(Shape shape);
  void _notifyRepositoryShapeDeleted(String shapeId);
  void _pushUndoState(Map<String, Shape> shapes);

  Rect _getTransformedBounds(Shape shape);

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
    if (state.enteredContainerId != null) {
      final enteredContainer = state.shapes[state.enteredContainerId!];
      if (enteredContainer != null) {
        // Walk up both parentId and frameId to find the parent container.
        final parentContainerId =
            enteredContainer.parentId ?? enteredContainer.frameId;
        final parentContainer =
            parentContainerId != null ? state.shapes[parentContainerId] : null;

        // Stay in the parent if it's a container (group or frame).
        final bool isParentEnterable = parentContainer != null &&
            (parentContainer is GroupShape || parentContainer is FrameShape);

        final nextEnteredContainerId =
            isParentEnterable ? parentContainerId : null;

        emit(
          state.copyWith(
            selectedShapeIds: [state.enteredContainerId!],
            expandedLayerIds:
                _expandAncestorsForShapes([state.enteredContainerId!]),
            enteredContainerId: nextEnteredContainerId,
            clearEnteredContainerId: nextEnteredContainerId == null,
            clearHoveredCornerIndex: true,
          ),
        );
      } else {
        emit(
          state.copyWith(
            selectedShapeIds: [],
            clearEnteredContainerId: true,
            clearHoveredCornerIndex: true,
          ),
        );
      }
    } else {
      emit(state.copyWith(selectedShapeIds: [], clearHoveredCornerIndex: true));
    }
  }

  void _onShapesReparented(
    ShapesReparented event,
    Emitter<CanvasState> emit,
  ) {
    if (event.shapeIds.isEmpty) return;

    final destinationGroupId = event.destinationGroupId;
    String? destinationFrameId = event.destinationFrameId;

    if (destinationGroupId != null) {
      final destinationGroup = state.shapes[destinationGroupId];
      if (destinationGroup is! GroupShape) return;
      destinationFrameId = destinationGroup.frameId;
    } else if (destinationFrameId != null) {
      final destinationFrame = state.shapes[destinationFrameId];
      if (destinationFrame is! FrameShape) {
        return;
      }
    }

    if (destinationGroupId != null) {
      final ancestorIds = LayerTreeBuilder.getAncestorIds(
        destinationGroupId,
        state.shapes,
      );
      final ancestorSet = <String>{destinationGroupId, ...ancestorIds};
      if (event.shapeIds.any(ancestorSet.contains)) return;
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

      final newParentId = destinationGroupId;
      final newFrameId = destinationFrameId;

      if (shape.frameId != newFrameId || shape.parentId != newParentId) {
        newShapes[id] = shape.copyWith(
          frameId: newFrameId,
          parentId: newParentId,
        );
        updatedShapeIds.add(id);
      }

      if (shape is GroupShape) {
        movedGroupIds.add(id);
      }
    }

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

    final frameIds = selected.map((s) => s.frameId).toSet();
    if (frameIds.length > 1) return;
    final groupFrameId = frameIds.isEmpty ? null : frameIds.first;

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

  Set<String> _expandAncestorsForShapes(List<String> shapeIds) {
    final expanded = Set<String>.from(state.expandedLayerIds);

    for (final shapeId in shapeIds) {
      final shape = state.shapes[shapeId];
      if (shape == null) continue;

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

        final children = shapesById.values
            .where((s) => s.parentId == group.id)
            .toList(growable: false)
          ..sort(compareZ);

        for (final child in children) {
          shapesById[child.id] = child.copyWith(parentId: group.parentId);
          _notifyRepositoryShapeUpdated(shapesById[child.id]!);
        }

        shapesById.remove(group.id);
        _notifyRepositoryShapeDeleted(group.id);

        siblings.removeAt(groupIndex);
        siblings.insertAll(groupIndex, children);

        for (final child in children) {
          newSelection.add(child.id);
        }
      }

      for (var i = 0; i < siblings.length; i++) {
        final shape = siblings[i];
        final updated = shapesById[shape.id];
        if (updated != null && updated.sortOrder != i) {
          shapesById[shape.id] = updated.copyWith(sortOrder: i);
          _notifyRepositoryShapeUpdated(shapesById[shape.id]!);
        }
      }
    }

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
}
