import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:vio_client/src/core/repositories/grpc_canvas_repository.dart';
import 'package:vio_client/src/gen/vio/v1/canvas.pb.dart' as pb;
import 'package:vio_client/src/gen/vio/v1/canvas.pbgrpc.dart';
import 'package:vio_core/vio_core.dart';

class _TestCanvasService extends CanvasServiceBase {
  int syncCallCount = 0;
  final List<DateTime> syncCallTimes = <DateTime>[];
  final List<pb.SyncChangesRequest> syncRequests = <pb.SyncChangesRequest>[];

  @override
  Future<pb.GetCanvasStateResponse> getCanvasState(
    ServiceCall call,
    pb.GetCanvasStateRequest request,
  ) async {
    return pb.GetCanvasStateResponse(
      state: pb.CanvasState(version: Int64.ZERO),
    );
  }

  @override
  Future<pb.SyncChangesResponse> syncChanges(
    ServiceCall call,
    pb.SyncChangesRequest request,
  ) async {
    syncCallCount++;
    syncCallTimes.add(DateTime.now());
    syncRequests.add(request.deepCopy());

    return pb.SyncChangesResponse(
      success: true,
      serverVersion: Int64(syncCallCount),
    );
  }

  @override
  Stream<pb.CanvasUpdate> streamUpdates(
    ServiceCall call,
    pb.StreamUpdatesRequest request,
  ) async* {}

  @override
  Stream<pb.CollaborateResponse> collaborate(
    ServiceCall call,
    Stream<pb.CollaborateRequest> request,
  ) async* {}

  @override
  Future<pb.RestoreFromSnapshotResponse> restoreFromSnapshot(
    ServiceCall call,
    pb.RestoreFromSnapshotRequest request,
  ) async {
    return pb.RestoreFromSnapshotResponse(success: true);
  }

  @override
  Future<pb.ClearWorkingCopyResponse> clearWorkingCopy(
    ServiceCall call,
    pb.ClearWorkingCopyRequest request,
  ) async {
    return pb.ClearWorkingCopyResponse(success: true);
  }
}

void main() {
  Future<void> waitForSyncCall(
    _TestCanvasService service, {
    required int targetCount,
    required Duration timeout,
  }) async {
    final startedAt = DateTime.now();
    while (service.syncCallCount < targetCount) {
      if (DateTime.now().difference(startedAt) > timeout) {
        fail(
          'Timed out waiting for sync call #$targetCount. '
          'Observed ${service.syncCallCount} call(s).',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  group('GrpcCanvasRepository update sync behavior', () {
    late Server server;
    late ClientChannel channel;
    late _TestCanvasService service;
    late GrpcCanvasRepository repository;

    setUp(() async {
      service = _TestCanvasService();
      server = Server.create(services: [service]);
      await server.serve(address: '127.0.0.1', port: 0);

      channel = ClientChannel(
        '127.0.0.1',
        port: server.port!,
        options: const ChannelOptions(
          credentials: ChannelCredentials.insecure(),
        ),
      );

      repository = GrpcCanvasRepository(
        canvasClient: CanvasServiceClient(channel),
        syncInterval: const Duration(seconds: 30),
      );

      const shape = RectangleShape(
        id: 'shape-1',
        name: 'Rect',
        x: 10,
        y: 20,
        rectWidth: 100,
        rectHeight: 80,
      );

      repository.setShapesFromSnapshot(
        const [shape],
        projectId: 'project-1',
        branchId: 'branch-1',
      );
    });

    tearDown(() async {
      await repository.sync();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      repository.dispose();
      await channel.shutdown();
      await server.shutdown();
    });

    test('structural update syncs immediately', () async {
      const original = RectangleShape(
        id: 'shape-1',
        name: 'Rect',
        x: 10,
        y: 20,
        rectWidth: 100,
        rectHeight: 80,
      );

      final movedIntoFrame = original.copyWith(frameId: 'frame-1');

      final startedAt = DateTime.now();

      repository.updateShape(movedIntoFrame);

      await waitForSyncCall(
        service,
        targetCount: 1,
        timeout: const Duration(seconds: 2),
      );
      final elapsed = DateTime.now().difference(startedAt);

      expect(service.syncCallCount, 1);
      expect(elapsed, lessThan(const Duration(milliseconds: 400)));
      expect(service.syncRequests.single.operations.single.shapeId, 'shape-1');
    });

    test('non-structural update remains debounced', () async {
      const original = RectangleShape(
        id: 'shape-1',
        name: 'Rect',
        x: 10,
        y: 20,
        rectWidth: 100,
        rectHeight: 80,
      );

      final renamed = original.copyWith(name: 'Renamed');

      final startedAt = DateTime.now();

      repository.updateShape(renamed);

      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(service.syncCallCount, 0);

      await waitForSyncCall(
        service,
        targetCount: 1,
        timeout: const Duration(seconds: 2),
      );
      final elapsed = DateTime.now().difference(startedAt);

      expect(service.syncCallCount, 1);
      expect(elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 450)));
      expect(service.syncRequests.single.operations.single.shapeId, 'shape-1');
    });
  });
}
