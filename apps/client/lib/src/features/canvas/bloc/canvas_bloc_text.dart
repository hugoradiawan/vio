part of 'canvas_bloc.dart';

mixin _CanvasTextMixin on Bloc<CanvasEvent, CanvasState> {
  Set<String> _expandAncestorsForShapes(List<String> shapeIds);
  void _notifyRepositoryShapeAdded(Shape shape);
  void _notifyRepositoryShapeUpdated(Shape shape);
  void _notifyRepositoryShapeDeleted(String shapeId);
  void _pushUndoState(Map<String, Shape> shapes);

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
}
