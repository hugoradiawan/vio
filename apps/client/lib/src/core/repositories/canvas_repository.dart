import 'dart:async';

import 'package:vio_core/vio_core.dart';

import '../api/api.dart';

/// Repository that manages canvas state with auto-sync to the backend
///
/// Implements last-write-wins conflict resolution strategy:
/// - Local changes are immediately applied
/// - Changes are periodically synced to server
/// - Server version always wins on conflict
class CanvasRepository {
  CanvasRepository({
    required CanvasApiService canvasService,
    Duration syncInterval = const Duration(seconds: 5),
  })  : _canvasService = canvasService,
        _syncInterval = syncInterval;

  final CanvasApiService _canvasService;
  final Duration _syncInterval;

  // Project/Branch context
  String? _projectId;
  String? _branchId;

  // Local state
  final List<Shape> _shapes = [];
  int _localVersion = 0;
  bool _isDirty = false;

  // Pending operations for sync
  final List<SyncOperation> _pendingOperations = [];

  // Sync timer
  Timer? _syncTimer;
  bool _isSyncing = false;

  // Stream controllers for state updates
  final _shapesController = StreamController<List<Shape>>.broadcast();
  final _syncStatusController = StreamController<SyncStatus>.broadcast();

  /// Stream of shape updates
  Stream<List<Shape>> get shapesStream => _shapesController.stream;

  /// Stream of sync status updates
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  /// Current shapes
  List<Shape> get shapes => List.unmodifiable(_shapes);

  /// Whether there are unsaved changes
  bool get isDirty => _isDirty;

  /// Current sync status
  SyncStatus _currentStatus = SyncStatus.idle;
  SyncStatus get syncStatus => _currentStatus;

  /// Initialize repository with a project and branch
  Future<void> initialize({
    required String projectId,
    required String branchId,
  }) async {
    _projectId = projectId;
    _branchId = branchId;

    // Load initial state from server
    await _loadFromServer();

    // Start auto-sync timer
    _startSyncTimer();
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _shapesController.close();
    _syncStatusController.close();
  }

  /// Load canvas state from server
  Future<void> _loadFromServer() async {
    if (_projectId == null || _branchId == null) return;

    _updateSyncStatus(SyncStatus.loading);

    try {
      final canvasState = await _canvasService.getCanvasState(
        _projectId!,
        _branchId!,
      );

      _shapes.clear();
      _shapes.addAll(canvasState.shapes);
      _localVersion = canvasState.version ?? 0;
      _isDirty = false;
      _pendingOperations.clear();

      _shapesController.add(shapes);
      _updateSyncStatus(SyncStatus.synced);

      VioLogger.info(
        'CanvasRepository: Loaded ${_shapes.length} shapes (v$_localVersion)',
      );
    } on ApiException catch (e) {
      VioLogger.error('CanvasRepository: Failed to load canvas state', e);
      _updateSyncStatus(SyncStatus.error);
      rethrow;
    }
  }

  /// Add a shape locally and queue for sync
  void addShape(Shape shape) {
    _shapes.add(shape);
    _isDirty = true;

    _pendingOperations.add(SyncOperation(
      type: SyncOperationType.create,
      shapeId: shape.id,
      shape: shape,
      timestamp: DateTime.now(),
    ),);

    _shapesController.add(shapes);
    _updateSyncStatus(SyncStatus.pending);
  }

  /// Update a shape locally and queue for sync
  void updateShape(Shape shape) {
    final index = _shapes.indexWhere((s) => s.id == shape.id);
    if (index == -1) {
      VioLogger.warning(
        'CanvasRepository: Attempted to update non-existent shape: ${shape.id}',
      );
      return;
    }

    _shapes[index] = shape;
    _isDirty = true;

    // Remove any pending operations for this shape and add new one
    _pendingOperations.removeWhere((op) => op.shapeId == shape.id);
    _pendingOperations.add(SyncOperation(
      type: SyncOperationType.update,
      shapeId: shape.id,
      shape: shape,
      timestamp: DateTime.now(),
    ),);

    _shapesController.add(shapes);
    _updateSyncStatus(SyncStatus.pending);
  }

  /// Delete a shape locally and queue for sync
  void deleteShape(String shapeId) {
    final index = _shapes.indexWhere((s) => s.id == shapeId);
    if (index == -1) {
      VioLogger.warning(
        'CanvasRepository: Attempted to delete non-existent shape: $shapeId',
      );
      return;
    }

    _shapes.removeAt(index);
    _isDirty = true;

    // Remove any pending operations for this shape and add delete
    _pendingOperations.removeWhere((op) => op.shapeId == shapeId);
    _pendingOperations.add(SyncOperation(
      type: SyncOperationType.delete,
      shapeId: shapeId,
      timestamp: DateTime.now(),
    ),);

    _shapesController.add(shapes);
    _updateSyncStatus(SyncStatus.pending);
  }

  /// Update multiple shapes at once
  void updateShapes(List<Shape> updatedShapes) {
    for (final shape in updatedShapes) {
      updateShape(shape);
    }
  }

  /// Replace all shapes (for undo/redo or full sync)
  void setShapes(List<Shape> newShapes) {
    _shapes.clear();
    _shapes.addAll(newShapes);
    _isDirty = true;
    _shapesController.add(shapes);
    _updateSyncStatus(SyncStatus.pending);
  }

  /// Start the auto-sync timer
  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) => _syncToServer());
  }

  /// Sync pending changes to server
  Future<void> _syncToServer() async {
    VioLogger.debug('CanvasRepository: Attempting to sync to server...');
    if (_projectId == null || _branchId == null) return;
    if (_isSyncing) return;
    if (_pendingOperations.isEmpty && !_isDirty) return;

    _isSyncing = true;
    _updateSyncStatus(SyncStatus.syncing);

    try {
      final response = await _canvasService.syncCanvas(
        projectId: _projectId!,
        branchId: _branchId!,
        shapes: _shapes,
        localVersion: _localVersion,
        operations: List.from(_pendingOperations),
      );

      if (response.success) {
        _localVersion = response.serverVersion;
        _pendingOperations.clear();
        _isDirty = false;

        // If server returned updated shapes (conflict resolution), apply them
        if (response.shapes != null) {
          _shapes.clear();
          _shapes.addAll(response.shapes!);
          _shapesController.add(shapes);

          VioLogger.info(
            'CanvasRepository: Server resolved conflicts, updated to v$_localVersion',
          );
        }

        _updateSyncStatus(SyncStatus.synced);

        VioLogger.info(
            'CanvasRepository: Synced successfully (v$_localVersion)',);
      } else {
        VioLogger.warning('CanvasRepository: Sync failed: ${response.message}');
        _updateSyncStatus(SyncStatus.error);
      }
    } on ApiException catch (e) {
      VioLogger.error('CanvasRepository: Sync error', e);
      _updateSyncStatus(SyncStatus.error);
    } finally {
      _isSyncing = false;
    }
  }

  /// Force an immediate sync
  Future<void> sync() async {
    await _syncToServer();
  }

  /// Refresh from server (discard local changes)
  Future<void> refresh() async {
    _pendingOperations.clear();
    await _loadFromServer();
  }

  void _updateSyncStatus(SyncStatus status) {
    _currentStatus = status;
    _syncStatusController.add(status);
  }
}

/// Sync status states
enum SyncStatus {
  /// Initial state, no operations pending
  idle,

  /// Loading initial data from server
  loading,

  /// Local changes pending sync
  pending,

  /// Currently syncing with server
  syncing,

  /// All changes synced
  synced,

  /// Sync error occurred
  error,
}
