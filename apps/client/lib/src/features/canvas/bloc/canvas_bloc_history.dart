part of 'canvas_bloc.dart';

mixin _CanvasHistoryMixin on Bloc<CanvasEvent, CanvasState> {
  List<Map<String, Shape>> get _undoStack;
  List<Map<String, Shape>> get _redoStack;

  /// Whether undo is available
  bool get canUndo => _undoStack.length > 1;

  /// Whether redo is available
  bool get canRedo => _redoStack.isNotEmpty;

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
}
