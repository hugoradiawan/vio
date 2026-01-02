import 'package:vio_core/vio_core.dart';

import '../api_client.dart';
import '../api_config.dart';
import '../dto.dart';

/// Service for canvas state and sync operations
class CanvasApiService {
  CanvasApiService({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  /// Get the current canvas state for a branch
  Future<CanvasStateDto> getCanvasState(
    String projectId,
    String branchId,
  ) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiConfig.endpoints.canvasState(projectId, branchId),
    );
    // Backend returns { data: { shapes, version, lastModified } }
    final data = response.data!['data'] as Map<String, dynamic>?;
    if (data != null) {
      return CanvasStateDto.fromJson(data);
    }
    return CanvasStateDto.fromJson(response.data!);
  }

  /// Sync local changes with the server
  /// Uses last-write-wins conflict resolution
  Future<SyncResponseDto> syncCanvas({
    required String projectId,
    required String branchId,
    required List<Shape> shapes,
    required int localVersion,
    required List<SyncOperation> operations,
  }) async {
    final request = SyncRequestDto(
      shapes: shapes,
      localVersion: localVersion,
      operations: operations,
    );

    final response = await _client.post<Map<String, dynamic>>(
      ApiConfig.endpoints.sync(projectId, branchId),
      data: request.toJson(),
    );

    return SyncResponseDto.fromJson(response.data!);
  }

  /// Create a new shape on the canvas (project-level)
  Future<Shape> createShape({
    required String projectId,
    required Shape shape,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiConfig.endpoints.projectShapes(projectId),
      data: shape.toJson(),
    );
    // Backend returns { data: shape }
    final data = response.data!['data'] as Map<String, dynamic>?;
    if (data != null) {
      return ShapeFactory.fromJson(data);
    }
    return ShapeFactory.fromJson(response.data!);
  }

  /// Update an existing shape
  Future<Shape> updateShape({
    required String projectId,
    required Shape shape,
  }) async {
    final response = await _client.put<Map<String, dynamic>>(
      ApiConfig.endpoints.projectShape(projectId, shape.id),
      data: shape.toJson(),
    );
    final data = response.data!['data'] as Map<String, dynamic>?;
    if (data != null) {
      return ShapeFactory.fromJson(data);
    }
    return ShapeFactory.fromJson(response.data!);
  }

  /// Delete a shape
  Future<void> deleteShape({
    required String projectId,
    required String shapeId,
  }) async {
    await _client.delete<void>(
      ApiConfig.endpoints.projectShape(projectId, shapeId),
    );
  }
}
