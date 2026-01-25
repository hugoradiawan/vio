import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';
import 'package:vio_core/vio_core.dart';

import '../../gen/vio/v1/canvas.pb.dart' as pb;
import '../../gen/vio/v1/canvas.pbgrpc.dart';
import '../grpc/proto_converter.dart';

/// Repository that manages canvas state with gRPC sync to the backend
///
/// Implements last-write-wins conflict resolution strategy:
/// - Local changes are immediately applied
/// - Changes are periodically synced to server via gRPC
/// - Server version always wins on conflict
class GrpcCanvasRepository {
  GrpcCanvasRepository({
    required CanvasServiceClient canvasClient,
    Duration syncInterval = const Duration(seconds: 5),
  })  : _canvasClient = canvasClient,
        _syncInterval = syncInterval;

  final CanvasServiceClient _canvasClient;
  final Duration _syncInterval;

  // Project/Branch context
  String? _projectId;
  String? _branchId;

  // Local state
  final List<Shape> _shapes = [];
  Int64 _localVersion = Int64.ZERO;
  bool _isDirty = false;

  // Pending operations for sync
  final List<_PendingOp> _pendingOperations = [];

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

  /// Load canvas state from server via gRPC
  Future<void> _loadFromServer() async {
    if (_projectId == null || _branchId == null) return;

    _updateSyncStatus(SyncStatus.loading);

    try {
      final request = pb.GetCanvasStateRequest()
        ..projectId = _projectId!
        ..branchId = _branchId!;

      final response = await _canvasClient.getCanvasState(request);

      _shapes.clear();
      for (final protoShape in response.state.shapes) {
        _shapes.add(ProtoConverter.shapeFromProto(protoShape));
      }
      _localVersion = response.state.version;
      _isDirty = false;
      _pendingOperations.clear();

      _shapesController.add(shapes);
      _updateSyncStatus(SyncStatus.synced);

      VioLogger.info(
        'GrpcCanvasRepository: Loaded ${_shapes.length} shapes (v$_localVersion)',
      );
    } on GrpcError catch (e) {
      VioLogger.error(
          'GrpcCanvasRepository: Failed to load canvas state - ${e.message}',);
      _updateSyncStatus(SyncStatus.error);
      rethrow;
    }
  }

  /// Add a shape locally and queue for sync
  void addShape(Shape shape) {
    _shapes.add(shape);
    _isDirty = true;

    _pendingOperations.add(
      _PendingOp(
        type: SyncOperationType.create,
        shapeId: shape.id,
        shape: shape,
        timestamp: DateTime.now(),
      ),
    );

    _shapesController.add(shapes);
    _updateSyncStatus(SyncStatus.pending);
  }

  /// Update a shape locally and queue for sync
  void updateShape(Shape shape) {
    final index = _shapes.indexWhere((s) => s.id == shape.id);
    if (index == -1) {
      VioLogger.warning(
        'GrpcCanvasRepository: Attempted to update non-existent shape: ${shape.id}',
      );
      return;
    }

    _shapes[index] = shape;
    _isDirty = true;

    // Remove any pending operations for this shape and add new one
    _pendingOperations.removeWhere((op) => op.shapeId == shape.id);
    _pendingOperations.add(
      _PendingOp(
        type: SyncOperationType.update,
        shapeId: shape.id,
        shape: shape,
        timestamp: DateTime.now(),
      ),
    );

    _shapesController.add(shapes);
    _updateSyncStatus(SyncStatus.pending);
  }

  /// Delete a shape locally and queue for sync
  void deleteShape(String shapeId) {
    final index = _shapes.indexWhere((s) => s.id == shapeId);
    if (index == -1) {
      VioLogger.warning(
        'GrpcCanvasRepository: Attempted to delete non-existent shape: $shapeId',
      );
      return;
    }

    _shapes.removeAt(index);
    _isDirty = true;

    // Remove any pending operations for this shape and add delete
    _pendingOperations.removeWhere((op) => op.shapeId == shapeId);
    _pendingOperations.add(
      _PendingOp(
        type: SyncOperationType.delete,
        shapeId: shapeId,
        timestamp: DateTime.now(),
      ),
    );

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

  /// Sync pending changes to server via gRPC
  Future<void> _syncToServer() async {
    if (_projectId == null || _branchId == null) return;
    if (_isSyncing) return;
    if (_pendingOperations.isEmpty && !_isDirty) return;

    VioLogger.debug(
      'GrpcCanvasRepository: Syncing ${_pendingOperations.length} operations...',
    );

    _isSyncing = true;
    _updateSyncStatus(SyncStatus.syncing);

    try {
      final request = pb.SyncChangesRequest()
        ..projectId = _projectId!
        ..branchId = _branchId!
        ..localVersion = _localVersion;

      // Convert pending operations to proto
      for (final op in _pendingOperations) {
        request.operations.add(
          ProtoConverter.syncOperationToProto(
            op.type,
            op.shapeId,
            op.shape,
            op.timestamp,
            _projectId,
          ),
        );
      }

      final response = await _canvasClient.syncChanges(request);

      if (response.success) {
        _localVersion = response.serverVersion;
        _pendingOperations.clear();
        _isDirty = false;

        // If server returned shapes (conflict resolution), apply them
        if (response.shapes.isNotEmpty) {
          _shapes.clear();
          for (final protoShape in response.shapes) {
            _shapes.add(ProtoConverter.shapeFromProto(protoShape));
          }
          _shapesController.add(shapes);

          VioLogger.info(
            'GrpcCanvasRepository: Server resolved conflicts, updated to v$_localVersion',
          );
        }

        _updateSyncStatus(SyncStatus.synced);

        VioLogger.info(
          'GrpcCanvasRepository: Synced successfully (v$_localVersion)',
        );
      } else {
        VioLogger.warning('GrpcCanvasRepository: Sync failed');
        _updateSyncStatus(SyncStatus.error);
      }
    } on GrpcError catch (e) {
      VioLogger.error('GrpcCanvasRepository: Sync error - ${e.message}');
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

/// Internal pending operation class
class _PendingOp {
  _PendingOp({
    required this.type,
    required this.shapeId,
    required this.timestamp,
    this.shape,
  });

  final SyncOperationType type;
  final String shapeId;
  final Shape? shape;
  final DateTime timestamp;
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
