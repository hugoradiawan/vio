part of 'canvas_bloc.dart';

mixin _CanvasInteractionMixin on Bloc<CanvasEvent, CanvasState> {
  int _nextSortOrderForNewShape({
    required Map<String, Shape> shapes,
    required String? parentId,
    required String? frameId,
  });

  Set<String> _expandAncestorsForShapes(List<String> shapeIds);

  Set<String> _expandAncestorsForShapesIn(
    Map<String, Shape> shapes,
    List<String> shapeIds,
    Set<String> currentExpanded,
  );

  void _beginSnapSession(Set<String> selectedIds);
  void _endSnapSession();
  bool _shouldRecomputeHover(Offset screenPoint);
  SnapResult _detectSnap(Offset dragOffset);

  _PruneEmptyGroupsResult _pruneEmptyGroups(Map<String, Shape> shapes);
  void _pushUndoState(Map<String, Shape> shapes);

  // Hit test delegation (from _CanvasRustMixin)
  Shape? findTopShapeAtPoint(Offset canvasPoint, List<Shape> shapeList);
  List<Shape> findShapesInRect(Rect rect, List<Shape> shapeList);

  void _notifyRepositoryShapeAdded(Shape shape);
  void _notifyRepositoryShapeUpdated(Shape shape);
  void _notifyRepositoryShapeDeleted(String shapeId);

  /// Find the innermost [FrameShape] whose bounds contain [canvasPoint].
  /// Returns `null` when the point is outside all frames (root canvas).
  FrameShape? _findContainingFrame(
    Offset canvasPoint,
    Map<String, Shape> shapes,
  ) {
    FrameShape? best;
    double bestArea = double.infinity;
    for (final shape in shapes.values) {
      if (shape is FrameShape && shape.bounds.contains(canvasPoint)) {
        final area = shape.bounds.width * shape.bounds.height;
        if (area < bestArea) {
          best = shape;
          bestArea = area;
        }
      }
    }
    return best;
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

      final containingFrame = _findContainingFrame(canvasPoint, state.shapes);
      final frameId = containingFrame?.id;

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
        event.tool != CanvasPointerTool.directSelect &&
        state.interactionMode != InteractionMode.drawing) {
      final newId = _uuid.v4();

      final containingFrame = _findContainingFrame(canvasPoint, state.shapes);
      final frameId = containingFrame?.id;

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
        CanvasPointerTool.directSelect => throw StateError('Unreachable'),
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

      // Check resize/rotate handles and edge affordances
      final hit = _hitTestSelectionAffordance(screenPoint);
      if (hit != null) {
        final handle = hit.effectiveHandle;
        if (handle == HandlePosition.rotation) {
          // Start rotation - calculate initial angle from selection center
          final bounds = state.selectionRect;
          final center = bounds?.center ?? canvasPoint;
          final initialAngle = _calculateRotationAngle(canvasPoint, center);
          emit(
            state.copyWith(
              interactionMode: InteractionMode.rotating,
              activeHandle: handle.name,
              dragStart: canvasPoint,
              currentPointer: canvasPoint,
              originalShapeBounds: bounds,
              originalShapes: Map.from(state.shapes),
              initialRotationAngle: initialAngle,
              selectionCursorKind: SelectionCursorKind.rotate,
            ),
          );
        } else {
          // Start resize - store original shapes for relative position calculation
          // Use un-rotated bounds so resize math works in axis-aligned space.
          final bounds = state.unrotatedSelectionRect ?? state.selectionRect;
          final resizeOrigin = _getResizeOrigin(handle, bounds);
          emit(
            state.copyWith(
              interactionMode: InteractionMode.resizing,
              activeHandle: handle.name,
              resizeOrigin: resizeOrigin,
              dragStart: canvasPoint,
              currentPointer: canvasPoint,
              originalShapeBounds: bounds,
              originalShapes: Map.from(state.shapes),
              selectionCursorKind: _selectionCursorKindForHandle(handle),
            ),
          );
        }
        return;
      }
    }

    // Hit test to find shape under pointer.
    // When inside an entered container, prefer shapes that are descendants of
    // that container so overlapping siblings don't cause an unwanted exit.
    Shape? hitShape;
    if (state.enteredContainerId != null) {
      final allHits = HitTest.findShapesAtPoint(canvasPoint, state.shapeList);
      hitShape = allHits.cast<Shape?>().firstWhere(
                (s) => HitTest.isDescendantOf(
                  s!,
                  state.enteredContainerId!,
                  state.shapes,
                ),
                orElse: () => null,
              ) ??
          allHits.firstOrNull;
    } else {
      hitShape = findTopShapeAtPoint(canvasPoint, state.shapeList);
    }

    if (hitShape != null) {
      // Resolve the correct selection target based on group drill-down state.
      // DirectSelect always picks the leaf; Select uses group-aware logic.
      final bool isDirectSelect = event.tool == CanvasPointerTool.directSelect;

      Shape selectionTarget;
      bool shouldClearEnteredGroup = false;

      if (isDirectSelect) {
        selectionTarget = hitShape;
        shouldClearEnteredGroup = state.enteredContainerId != null;
      } else if (state.enteredContainerId != null) {
        if (hitShape.id == state.enteredContainerId ||
            !HitTest.isDescendantOf(
              hitShape,
              state.enteredContainerId!,
              state.shapes,
            )) {
          // Clicked on the entered group's background or outside it.
          // Exit the entered group and do normal (outermost-group) selection.
          selectionTarget =
              HitTest.resolveContainerTarget(hitShape, state.shapes);
          shouldClearEnteredGroup = true;
        } else {
          // Clicked on a descendant — select the direct child of the entered
          // group that contains this shape.
          selectionTarget = HitTest.resolveContainerTarget(
            hitShape,
            state.shapes,
            enteredContainerId: state.enteredContainerId,
          );
        }
      } else {
        // Not inside any group — select the outermost container ancestor.
        selectionTarget =
            HitTest.resolveContainerTarget(hitShape, state.shapes);
      }

      // Check if shift is held for multi-select
      final addToSelection = event.shiftPressed;

      if (addToSelection) {
        // Toggle selection
        if (state.selectedShapeIds.contains(selectionTarget.id)) {
          _endSnapSession();
          emit(
            state.copyWith(
              selectedShapeIds: state.selectedShapeIds
                  .where((id) => id != selectionTarget.id)
                  .toList(),
              interactionMode: InteractionMode.idle,
              clearDragStart: true,
              clearCurrentPointer: true,
              clearEnteredContainerId: shouldClearEnteredGroup,
            ),
          );
        } else {
          final newSelection = [
            ...state.selectedShapeIds,
            selectionTarget.id,
          ];
          _beginSnapSession(newSelection.toSet());
          emit(
            state.copyWith(
              selectedShapeIds: newSelection,
              expandedLayerIds: _expandAncestorsForShapes(newSelection),
              interactionMode: InteractionMode.movingShapes,
              dragStart: canvasPoint,
              currentPointer: canvasPoint,
              clearEnteredContainerId: shouldClearEnteredGroup,
            ),
          );
        }
      } else {
        // Single selection
        final isAlreadySelected =
            state.selectedShapeIds.contains(selectionTarget.id);
        final newSelection =
            isAlreadySelected ? state.selectedShapeIds : [selectionTarget.id];

        _beginSnapSession(newSelection.toSet());
        emit(
          state.copyWith(
            selectedShapeIds: newSelection,
            expandedLayerIds: _expandAncestorsForShapes(newSelection),
            interactionMode: InteractionMode.movingShapes,
            dragStart: canvasPoint,
            currentPointer: canvasPoint,
            clearEnteredContainerId: shouldClearEnteredGroup,
          ),
        );
      }
    } else {
      // No shape hit - start marquee selection, exit any entered group
      _endSnapSession();
      emit(
        state.copyWith(
          interactionMode: InteractionMode.dragging,
          dragStart: canvasPoint,
          currentPointer: canvasPoint,
          selectedShapeIds: [], // Clear selection
          clearEnteredContainerId: true,
        ),
      );
    }
  }

  void _onCanvasDoubleClicked(
    CanvasDoubleClicked event,
    Emitter<CanvasState> emit,
  ) {
    // Double-click only acts on a single selected shape.
    if (state.selectedShapeIds.length != 1) return;

    final selectedShape = state.shapes[state.selectedShapeIds.first];
    if (selectedShape == null) return;

    // Double-click on a TextShape → start inline text editing.
    if (selectedShape is TextShape) {
      add(TextEditRequested(shapeId: selectedShape.id));
      return;
    }

    // Double-click on a GroupShape or FrameShape — drill into the container.
    if (selectedShape is GroupShape || selectedShape is FrameShape) {
      final screenPoint = Offset(event.x, event.y);
      final canvasPoint = _screenToCanvas(screenPoint);

      // Find the topmost shape under the cursor that is a descendant of the
      // selected container. We can't use findTopShapeAtPoint because a sibling
      // shape may overlap the container's children at the click position.
      final allHits = HitTest.findShapesAtPoint(canvasPoint, state.shapeList);
      final hitShape = allHits.cast<Shape?>().firstWhere(
            (s) =>
                s!.id != selectedShape.id &&
                HitTest.isDescendantOf(s, selectedShape.id, state.shapes),
            orElse: () => null,
          );

      if (hitShape != null) {
        // Resolve the direct child of the newly-entered container.
        final target = HitTest.resolveContainerTarget(
          hitShape,
          state.shapes,
          enteredContainerId: selectedShape.id,
        );

        final newSelection = [target.id];
        emit(
          state.copyWith(
            enteredContainerId: selectedShape.id,
            selectedShapeIds: newSelection,
            expandedLayerIds: _expandAncestorsForShapes(newSelection),
            interactionMode: InteractionMode.idle,
            clearDragStart: true,
            clearCurrentPointer: true,
            clearDragOffset: true,
            clearSnap: true,
          ),
        );
      } else {
        // Nothing under cursor inside the container — enter but clear selection.
        emit(
          state.copyWith(
            enteredContainerId: selectedShape.id,
            selectedShapeIds: const [],
            interactionMode: InteractionMode.idle,
            clearDragStart: true,
            clearCurrentPointer: true,
            clearDragOffset: true,
            clearSnap: true,
          ),
        );
      }
      return;
    }

    // For other shape types, double-click is a no-op.
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

      // Un-rotate the pointer into the axis-aligned frame of the selection
      // so existing resize math works unchanged for rotated shapes.
      final rotDeg = _selectionRotationDegrees();
      Offset resizePointer = canvasPoint;
      if (rotDeg.abs() > 0.01) {
        final center = state.originalShapeBounds!.center;
        final radians = -rotDeg * math.pi / 180.0;
        final cosA = math.cos(radians);
        final sinA = math.sin(radians);
        final dx = canvasPoint.dx - center.dx;
        final dy = canvasPoint.dy - center.dy;
        resizePointer = Offset(
          center.dx + dx * cosA - dy * sinA,
          center.dy + dx * sinA + dy * cosA,
        );
      }

      final newShapes = _calculateResize(
        resizePointer,
        handle,
        state.resizeOrigin!,
        state.originalShapeBounds!,
        shiftPressed: event.shiftPressed,
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

      // Resolve to the correct container level so the hover outline matches what
      // a click would actually select. When inside an entered container, prefer
      // descendants so overlapping siblings don't flicker the hover.
      Shape? hoveredLeaf;
      if (state.enteredContainerId != null) {
        final allHits = HitTest.findShapesAtPoint(canvasPoint, state.shapeList);
        hoveredLeaf = allHits.cast<Shape?>().firstWhere(
                  (s) => HitTest.isDescendantOf(
                    s!,
                    state.enteredContainerId!,
                    state.shapes,
                  ),
                  orElse: () => null,
                ) ??
            allHits.firstOrNull;
      } else {
        hoveredLeaf = findTopShapeAtPoint(canvasPoint, state.shapeList);
      }
      String? newHoveredId;
      if (hoveredLeaf != null) {
        final target = HitTest.resolveContainerTarget(
          hoveredLeaf,
          state.shapes,
          enteredContainerId: state.enteredContainerId,
        );
        newHoveredId = target.id;
      }

      final nextHoveredCornerIndex = hoveredCorner?.index;
      final hoveredSelectionHit = _hitTestSelectionAffordance(screenPoint);
      final nextSelectionCursorKind = hoveredSelectionHit == null
          ? SelectionCursorKind.none
          : _selectionCursorKindForHandle(
              hoveredSelectionHit.effectiveHandle,
            );

      // Only emit if hovered shape changed
      if (newHoveredId != state.hoveredShapeId ||
          nextHoveredCornerIndex != state.hoveredCornerIndex ||
          nextSelectionCursorKind != state.selectionCursorKind) {
        if (newHoveredId == null) {
          emit(
            state.copyWith(
              currentPointer: canvasPoint,
              clearHoveredShapeId: true,
              hoveredCornerIndex: nextHoveredCornerIndex,
              clearHoveredCornerIndex: nextHoveredCornerIndex == null,
              selectionCursorKind: nextSelectionCursorKind,
            ),
          );
        } else {
          emit(
            state.copyWith(
              currentPointer: canvasPoint,
              hoveredShapeId: newHoveredId,
              hoveredCornerIndex: nextHoveredCornerIndex,
              clearHoveredCornerIndex: nextHoveredCornerIndex == null,
              selectionCursorKind: nextSelectionCursorKind,
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
      final shapesInRect = findShapesInRect(
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
          // Use the transform matrix (ground truth) to detect rotation,
          // not the shape.rotation field which can drift out of sync.
          final hasRotation = shape.transform.rotation.abs() > 0.001;
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

  /// Hit test for selection resize/rotate handles and edge lines.
  SelectionHitResult? _hitTestSelectionAffordance(Offset screenPoint) {
    if (state.selectedShapes.any((s) => s.blocked)) return null;

    final bounds = state.unrotatedSelectionRect ?? state.selectionRect;
    if (bounds == null) return null;

    final isSingleTextSelection = state.selectedShapes.length == 1 &&
        state.selectedShapes.first is TextShape;

    return hitTestSelectionAffordance(
      screenPoint: screenPoint,
      selectionBounds: bounds,
      zoom: state.zoom,
      viewportOffset: state.viewportOffset,
      isSingleTextSelection: isSingleTextSelection,
      selectionRotationDegrees: state.selectionRotation,
    );
  }

  SelectionCursorKind _selectionCursorKindForHandle(HandlePosition handle) {
    if (handle == HandlePosition.rotation) {
      return SelectionCursorKind.rotate;
    }

    Offset axisVectorFor(HandlePosition position) {
      switch (position) {
        case HandlePosition.topLeft:
          return const Offset(-1, -1);
        case HandlePosition.topCenter:
          return const Offset(0, -1);
        case HandlePosition.topRight:
          return const Offset(1, -1);
        case HandlePosition.middleLeft:
          return const Offset(-1, 0);
        case HandlePosition.middleRight:
          return const Offset(1, 0);
        case HandlePosition.bottomLeft:
          return const Offset(-1, 1);
        case HandlePosition.bottomCenter:
          return const Offset(0, 1);
        case HandlePosition.bottomRight:
          return const Offset(1, 1);
        case HandlePosition.rotation:
          return const Offset(0, -1);
      }
    }

    final vector = axisVectorFor(handle);
    final radians = _selectionRotationDegrees() * math.pi / 180.0;
    final cosA = math.cos(radians);
    final sinA = math.sin(radians);
    final rotated = Offset(
      vector.dx * cosA - vector.dy * sinA,
      vector.dx * sinA + vector.dy * cosA,
    );

    final angleDeg = math.atan2(rotated.dy, rotated.dx) * 180.0 / math.pi;
    final axisDeg = ((angleDeg % 180.0) + 180.0) % 180.0;

    const horizontal = 0.0;
    const diagonalPrimary = 45.0;
    const vertical = 90.0;
    const diagonalSecondary = 135.0;

    double circularDistance(double a, double b) {
      final diff = (a - b).abs();
      return diff > 90.0 ? 180.0 - diff : diff;
    }

    final distances = <SelectionCursorKind, double>{
      SelectionCursorKind.resizeHorizontal:
          circularDistance(axisDeg, horizontal),
      SelectionCursorKind.resizeDiagonalPrimary:
          circularDistance(axisDeg, diagonalPrimary),
      SelectionCursorKind.resizeVertical: circularDistance(axisDeg, vertical),
      SelectionCursorKind.resizeDiagonalSecondary:
          circularDistance(axisDeg, diagonalSecondary),
    };

    return distances.entries.reduce((a, b) => a.value <= b.value ? a : b).key;
  }

  double _selectionRotationDegrees() {
    final selected = state.selectedShapes;
    if (selected.isEmpty) return 0;

    double rotDeg(Shape s) => s.transform.rotation * 180.0 / math.pi;

    if (selected.length == 1) return rotDeg(selected.first);

    final first = rotDeg(selected.first);
    final allMatch =
        selected.every((shape) => (rotDeg(shape) - first).abs() < 0.5);
    return allMatch ? first : 0;
  }

  /// Hit test for corner radius handles
  _CornerRadiusHit? _hitTestCornerRadiusHandle(Offset screenPoint) {
    if (state.selectedShapes.length != 1) return null;

    final shape = state.selectedShapes.first;
    if (shape.blocked) return null;
    if (shape is! RectangleShape) return null;

    final positions = _getCornerRadiusHandlePositions(shape);
    const hitRadius = SelectionHandleMetrics.cornerRadiusHitRadius;
    for (var i = 0; i < positions.length; i++) {
      final screenHandlePos = _canvasToScreen(positions[i]);
      final distance = (screenPoint - screenHandlePos).distance;
      if (distance <= hitRadius) {
        return _CornerRadiusHit(index: i, position: positions[i]);
      }
    }
    return null;
  }

  /// Get corner radius handle positions in canvas coordinates
  List<Offset> _getCornerRadiusHandlePositions(RectangleShape rect) {
    final bounds = rect.bounds;

    final minInset = SelectionHandleMetrics.toCanvasUnits(
      screenPx: SelectionHandleMetrics.cornerRadiusMinInset,
      zoom: state.zoom,
    );
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
    Rect originalBounds, {
    bool shiftPressed = false,
  }) {
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
    double newWidth = (newRight - newLeft).clamp(1.0, double.infinity);
    double newHeight = (newBottom - newTop).clamp(1.0, double.infinity);

    // Shift+resize: constrain to original aspect ratio
    if (shiftPressed && originalWidth > 0 && originalHeight > 0) {
      final aspectRatio = originalWidth / originalHeight;
      final isCorner = handle == HandlePosition.topLeft ||
          handle == HandlePosition.topRight ||
          handle == HandlePosition.bottomLeft ||
          handle == HandlePosition.bottomRight;
      final isHorizontalEdge = handle == HandlePosition.middleLeft ||
          handle == HandlePosition.middleRight;

      if (isCorner) {
        // Use the dominant axis to determine the new size
        if (newWidth / aspectRatio > newHeight) {
          newHeight = newWidth / aspectRatio;
        } else {
          newWidth = newHeight * aspectRatio;
        }
      } else if (isHorizontalEdge) {
        newHeight = newWidth / aspectRatio;
      } else {
        // Vertical edge
        newWidth = newHeight * aspectRatio;
      }

      // Re-anchor the constrained size to the correct corner/edge
      switch (handle) {
        case HandlePosition.topLeft:
          newLeft = newRight - newWidth;
          newTop = newBottom - newHeight;
        case HandlePosition.topCenter:
          newTop = newBottom - newHeight;
          final cx = (newLeft + newRight) / 2;
          newLeft = cx - newWidth / 2;
          newRight = cx + newWidth / 2;
        case HandlePosition.topRight:
          newRight = newLeft + newWidth;
          newTop = newBottom - newHeight;
        case HandlePosition.middleLeft:
          newLeft = newRight - newWidth;
          final cy = (newTop + newBottom) / 2;
          newTop = cy - newHeight / 2;
          newBottom = cy + newHeight / 2;
        case HandlePosition.middleRight:
          newRight = newLeft + newWidth;
          final cy = (newTop + newBottom) / 2;
          newTop = cy - newHeight / 2;
          newBottom = cy + newHeight / 2;
        case HandlePosition.bottomLeft:
          newLeft = newRight - newWidth;
          newBottom = newTop + newHeight;
        case HandlePosition.bottomCenter:
          newBottom = newTop + newHeight;
          final cx = (newLeft + newRight) / 2;
          newLeft = cx - newWidth / 2;
          newRight = cx + newWidth / 2;
        case HandlePosition.bottomRight:
          newRight = newLeft + newWidth;
          newBottom = newTop + newHeight;
        case HandlePosition.rotation:
          break;
      }
    }

    // Apply resize to each selected shape
    for (final shapeId in state.selectedShapeIds) {
      // Use ORIGINAL shape bounds for calculating relative position
      final originalShape = originalShapes?[shapeId];
      final currentShape = newShapes[shapeId];
      if (originalShape == null || currentShape == null) continue;
      if (originalShape.blocked) continue;

      // For rotated selections, we need the shape bounds in the un-rotated
      // selection frame (not the local shape frame) so that relative
      // positioning within the combined selection rect is correct.
      final rotDeg = _selectionRotationDegrees();
      final Rect originalShapeBounds;
      if (rotDeg.abs() > 0.01) {
        final center = originalBounds.center;
        final radians = -rotDeg * math.pi / 180.0;
        final cosA = math.cos(radians);
        final sinA = math.sin(radians);
        Offset unrotate(Offset p) {
          final dx = p.dx - center.dx;
          final dy = p.dy - center.dy;
          return Offset(
            center.dx + dx * cosA - dy * sinA,
            center.dy + dx * sinA + dy * cosA,
          );
        }

        final localBounds = originalShape.bounds;
        final corners = [
          originalShape
              .transformPoint(Offset(localBounds.left, localBounds.top)),
          originalShape
              .transformPoint(Offset(localBounds.right, localBounds.top)),
          originalShape
              .transformPoint(Offset(localBounds.right, localBounds.bottom)),
          originalShape
              .transformPoint(Offset(localBounds.left, localBounds.bottom)),
        ];
        var sMinX = double.infinity;
        var sMinY = double.infinity;
        var sMaxX = -double.infinity;
        var sMaxY = -double.infinity;
        for (final c in corners) {
          final ur = unrotate(c);
          sMinX = math.min(sMinX, ur.dx);
          sMinY = math.min(sMinY, ur.dy);
          sMaxX = math.max(sMaxX, ur.dx);
          sMaxY = math.max(sMaxY, ur.dy);
        }
        originalShapeBounds = Rect.fromLTRB(sMinX, sMinY, sMaxX, sMaxY);
      } else {
        originalShapeBounds = originalShape.bounds;
      }
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

      // For rotated selections, keep local x/y and rebuild the transform.
      // The resized position is in the un-rotated selection frame — we need to
      // re-rotate to get the correct world-space transform.
      double finalX;
      double finalY;
      Matrix2D? finalTransform;
      if (rotDeg.abs() > 0.01) {
        // Keep the original local x/y — only scale dimensions.
        finalX = originalShape.x;
        finalY = originalShape.y;
        final localCenterX = finalX + shapeNewWidth / 2;
        final localCenterY = finalY + shapeNewHeight / 2;

        // Where the center should be in the un-rotated selection frame:
        final urCenterX = shapeNewX + shapeNewWidth / 2;
        final urCenterY = shapeNewY + shapeNewHeight / 2;

        // Re-rotate to get world center:
        final selCenter = originalBounds.center;
        final reRotRadians = rotDeg * math.pi / 180.0;
        final cosR = math.cos(reRotRadians);
        final sinR = math.sin(reRotRadians);
        final dxUR = urCenterX - selCenter.dx;
        final dyUR = urCenterY - selCenter.dy;
        final worldCenterX = selCenter.dx + dxUR * cosR - dyUR * sinR;
        final worldCenterY = selCenter.dy + dxUR * sinR + dyUR * cosR;

        // Build transform: rotate around local center, then translate so
        // local center maps to world center.
        final shapeRotRadians = originalShape.transform.rotation;
        final rotMatrix =
            Matrix2D.rotationAt(shapeRotRadians, localCenterX, localCenterY);
        // rotMatrix maps localCenter → localCenter (rotation in-place).
        // We need localCenter → worldCenter, so add a translation.
        final rotatedLC = rotMatrix.transformPoint(localCenterX, localCenterY);
        finalTransform = rotMatrix.copyWith(
          e: rotMatrix.e + (worldCenterX - rotatedLC.x),
          f: rotMatrix.f + (worldCenterY - rotatedLC.y),
        );
      } else {
        finalX = shapeNewX;
        finalY = shapeNewY;
      }

      // Apply to shape based on type (use originalShape as base for copyWith)
      if (originalShape is RectangleShape) {
        newShapes[shapeId] = originalShape.copyWith(
          x: finalX,
          y: finalY,
          rectWidth: shapeNewWidth,
          rectHeight: shapeNewHeight,
          transform: finalTransform,
        );
      } else if (originalShape is EllipseShape) {
        newShapes[shapeId] = originalShape.copyWith(
          x: finalX,
          y: finalY,
          ellipseWidth: shapeNewWidth,
          ellipseHeight: shapeNewHeight,
          transform: finalTransform,
        );
      } else if (originalShape is FrameShape) {
        newShapes[shapeId] = originalShape.copyWith(
          x: finalX,
          y: finalY,
          frameWidth: shapeNewWidth,
          frameHeight: shapeNewHeight,
          transform: finalTransform,
        );
      } else if (originalShape is TextShape) {
        newShapes[shapeId] = originalShape.copyWith(
          x: finalX,
          y: finalY,
          textWidth: shapeNewWidth,
          textHeight: shapeNewHeight,
          transform: finalTransform,
        );
      } else if (originalShape is ImageShape) {
        newShapes[shapeId] = originalShape.copyWith(
          x: finalX,
          y: finalY,
          imageWidth: shapeNewWidth,
          imageHeight: shapeNewHeight,
          transform: finalTransform,
        );
      } else if (originalShape is SvgShape) {
        newShapes[shapeId] = originalShape.copyWith(
          x: finalX,
          y: finalY,
          svgWidth: shapeNewWidth,
          svgHeight: shapeNewHeight,
          transform: finalTransform,
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
}
