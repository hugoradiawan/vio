part of 'canvas_bloc.dart';

mixin _CanvasSyncMixin on Bloc<CanvasEvent, CanvasState> {
  GrpcCanvasRepository? get _repository;
  List<Map<String, Shape>> get _undoStack;
  List<Map<String, Shape>> get _redoStack;

  // Rust engine state (from _CanvasRustMixin)
  RustEngineService get _rustEngine;
  set _rustEngineLoaded(bool value);
  set _lastRustSyncedShapes(Map<String, Shape> value);

  /// Subscription for repository sync status changes
  StreamSubscription<SyncStatus>? _syncStatusSubscription;

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
      await _syncStatusSubscription?.cancel();
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

    // Reset Rust engine so the next onChange triggers a fresh bulk load.
    _rustEngine.reset();
    _rustEngineLoaded = false;
    _lastRustSyncedShapes = const {};

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
}
