import 'dart:async';
import 'dart:convert';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:vio_client/src/features/canvas/bloc/canvas_bloc.dart';

class CanvasPerformanceDiagnostics {
  static const bool _enabled = bool.fromEnvironment(
    'VIO_CANVAS_PERF_DIAGNOSTICS',
  );

  static const Duration _wheelSessionGap = Duration(milliseconds: 180);

  bool get isEnabled => _enabled;

  int? _dragPanStartMs;
  int _dragPanEventCount = 0;
  double _dragPanDistance = 0;

  int? _gestureZoomStartMs;
  int _gestureZoomEventCount = 0;
  int _gesturePanEventCount = 0;
  double _gestureZoomScaleProduct = 1;
  double _gesturePanDistance = 0;

  int? _wheelPanStartMs;
  int _wheelPanEventCount = 0;
  double _wheelPanDistance = 0;
  Timer? _wheelPanFlushTimer;

  int? _wheelZoomStartMs;
  int _wheelZoomEventCount = 0;
  double _wheelZoomScaleProduct = 1;
  Timer? _wheelZoomFlushTimer;

  bool _frameTrackingActive = false;
  int _trackedFrameCount = 0;
  int _jankFrameCount = 0;
  Duration _sumFrameTotal = Duration.zero;
  Duration _sumBuild = Duration.zero;
  Duration _sumRaster = Duration.zero;
  Duration _worstFrame = Duration.zero;

  void onDragPanStart(CanvasState canvasState, {required String source}) {
    if (!_enabled || _dragPanStartMs != null) return;
    _startFrameTracking();
    _dragPanStartMs = DateTime.now().millisecondsSinceEpoch;
    _dragPanEventCount = 0;
    _dragPanDistance = 0;

    _emit(
      operation: 'canvas.drag_pan.start',
      canvasState: canvasState,
      metrics: {'source': source},
    );
  }

  void onDragPanUpdate(Offset delta, CanvasState canvasState) {
    if (!_enabled || _dragPanStartMs == null) return;
    _dragPanEventCount += 1;
    _dragPanDistance += delta.distance;

    if (_dragPanEventCount % 30 == 0) {
      _emit(
        operation: 'canvas.drag_pan.sample',
        canvasState: canvasState,
        metrics: {
          'eventCount': _dragPanEventCount,
          'distancePx': _round(_dragPanDistance),
        },
      );
    }
  }

  void onDragPanEnd(CanvasState canvasState) {
    if (!_enabled || _dragPanStartMs == null) return;

    final durationMs = DateTime.now().millisecondsSinceEpoch - _dragPanStartMs!;
    _emit(
      operation: 'canvas.drag_pan.end',
      canvasState: canvasState,
      metrics: {
        'durationMs': durationMs,
        'eventCount': _dragPanEventCount,
        'distancePx': _round(_dragPanDistance),
        ..._frameSummary(),
      },
    );

    _dragPanStartMs = null;
    _dragPanEventCount = 0;
    _dragPanDistance = 0;
    _stopFrameTracking();
  }

  void onGestureZoomStart(CanvasState canvasState) {
    if (!_enabled || _gestureZoomStartMs != null) return;
    _startFrameTracking();
    _gestureZoomStartMs = DateTime.now().millisecondsSinceEpoch;
    _gestureZoomEventCount = 0;
    _gesturePanEventCount = 0;
    _gestureZoomScaleProduct = 1;
    _gesturePanDistance = 0;

    _emit(
      operation: 'canvas.gesture_zoom.start',
      canvasState: canvasState,
    );
  }

  void onGestureZoomUpdate(double scaleFactor, CanvasState canvasState) {
    if (!_enabled || _gestureZoomStartMs == null) return;
    _gestureZoomEventCount += 1;
    _gestureZoomScaleProduct *= scaleFactor;

    if (_gestureZoomEventCount % 20 == 0) {
      _emit(
        operation: 'canvas.gesture_zoom.sample',
        canvasState: canvasState,
        metrics: {
          'eventCount': _gestureZoomEventCount,
          'scaleProduct': _round(_gestureZoomScaleProduct),
        },
      );
    }
  }

  void onGesturePanUpdate(Offset delta, CanvasState canvasState) {
    if (!_enabled || _gestureZoomStartMs == null) return;
    _gesturePanEventCount += 1;
    _gesturePanDistance += delta.distance;

    if (_gesturePanEventCount % 20 == 0) {
      _emit(
        operation: 'canvas.gesture_pan.sample',
        canvasState: canvasState,
        metrics: {
          'eventCount': _gesturePanEventCount,
          'distancePx': _round(_gesturePanDistance),
        },
      );
    }
  }

  void onGestureZoomEnd(CanvasState canvasState) {
    if (!_enabled || _gestureZoomStartMs == null) return;

    final durationMs =
        DateTime.now().millisecondsSinceEpoch - _gestureZoomStartMs!;

    final isZoomSession = _gestureZoomEventCount > 0;
    final operation =
        isZoomSession ? 'canvas.gesture_zoom.end' : 'canvas.gesture_pan.end';
    final metrics = {
      'durationMs': durationMs,
      ..._frameSummary(),
    };

    if (isZoomSession) {
      metrics.addAll({
        'eventCount': _gestureZoomEventCount,
        'scaleProduct': _round(_gestureZoomScaleProduct),
      });
    } else {
      metrics.addAll({
        'eventCount': _gesturePanEventCount,
        'distancePx': _round(_gesturePanDistance),
      });
    }

    _emit(operation: operation, canvasState: canvasState, metrics: metrics);

    _gestureZoomStartMs = null;
    _gestureZoomEventCount = 0;
    _gesturePanEventCount = 0;
    _gestureZoomScaleProduct = 1;
    _gesturePanDistance = 0;
    _stopFrameTracking();
  }

  void onWheelPan({
    required double deltaX,
    required double deltaY,
    required CanvasState canvasState,
  }) {
    if (!_enabled) return;

    _startFrameTracking();
    _wheelPanStartMs ??= DateTime.now().millisecondsSinceEpoch;
    _wheelPanEventCount += 1;
    _wheelPanDistance += Offset(deltaX, deltaY).distance;

    _wheelPanFlushTimer?.cancel();
    _wheelPanFlushTimer = Timer(_wheelSessionGap, () {
      _flushWheelPan(canvasState);
    });
  }

  void onWheelZoom({
    required double scaleFactor,
    required CanvasState canvasState,
  }) {
    if (!_enabled) return;

    _startFrameTracking();
    _wheelZoomStartMs ??= DateTime.now().millisecondsSinceEpoch;
    _wheelZoomEventCount += 1;
    _wheelZoomScaleProduct *= scaleFactor;

    _wheelZoomFlushTimer?.cancel();
    _wheelZoomFlushTimer = Timer(_wheelSessionGap, () {
      _flushWheelZoom(canvasState);
    });
  }

  void dispose({CanvasState? lastState}) {
    if (!_enabled) return;

    _wheelPanFlushTimer?.cancel();
    _wheelZoomFlushTimer?.cancel();

    if (lastState != null) {
      _flushWheelPan(lastState);
      _flushWheelZoom(lastState);
      if (_dragPanStartMs != null) {
        onDragPanEnd(lastState);
      }
      if (_gestureZoomStartMs != null) {
        onGestureZoomEnd(lastState);
      }
    }

    _stopFrameTracking();
  }

  void _flushWheelPan(CanvasState canvasState) {
    if (_wheelPanStartMs == null) return;

    final durationMs =
        DateTime.now().millisecondsSinceEpoch - _wheelPanStartMs!;
    _emit(
      operation: 'canvas.wheel_pan.end',
      canvasState: canvasState,
      metrics: {
        'durationMs': durationMs,
        'eventCount': _wheelPanEventCount,
        'distancePx': _round(_wheelPanDistance),
        ..._frameSummary(),
      },
    );

    _wheelPanStartMs = null;
    _wheelPanEventCount = 0;
    _wheelPanDistance = 0;
    _stopFrameTracking();
  }

  void _flushWheelZoom(CanvasState canvasState) {
    if (_wheelZoomStartMs == null) return;

    final durationMs =
        DateTime.now().millisecondsSinceEpoch - _wheelZoomStartMs!;
    _emit(
      operation: 'canvas.wheel_zoom.end',
      canvasState: canvasState,
      metrics: {
        'durationMs': durationMs,
        'eventCount': _wheelZoomEventCount,
        'scaleProduct': _round(_wheelZoomScaleProduct),
        ..._frameSummary(),
      },
    );

    _wheelZoomStartMs = null;
    _wheelZoomEventCount = 0;
    _wheelZoomScaleProduct = 1;
    _stopFrameTracking();
  }

  void _startFrameTracking() {
    if (_frameTrackingActive) return;

    _frameTrackingActive = true;
    _trackedFrameCount = 0;
    _jankFrameCount = 0;
    _sumFrameTotal = Duration.zero;
    _sumBuild = Duration.zero;
    _sumRaster = Duration.zero;
    _worstFrame = Duration.zero;

    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
  }

  void _stopFrameTracking() {
    if (!_frameTrackingActive) return;

    final anyActive = _dragPanStartMs != null ||
        _gestureZoomStartMs != null ||
        _wheelPanStartMs != null ||
        _wheelZoomStartMs != null;
    if (anyActive) return;

    _frameTrackingActive = false;
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (!_enabled || !_frameTrackingActive) return;

    for (final timing in timings) {
      final total = timing.totalSpan;
      _trackedFrameCount += 1;
      _sumFrameTotal += total;
      _sumBuild += timing.buildDuration;
      _sumRaster += timing.rasterDuration;

      if (total > _worstFrame) {
        _worstFrame = total;
      }
      if (total.inMicroseconds > 16667) {
        _jankFrameCount += 1;
      }
    }
  }

  Map<String, Object> _frameSummary() {
    if (_trackedFrameCount == 0) {
      return {
        'frameCount': 0,
        'jankCount': 0,
        'avgFrameMs': 0,
        'avgBuildMs': 0,
        'avgRasterMs': 0,
        'worstFrameMs': 0,
      };
    }

    final frameCount = _trackedFrameCount;
    final avgFrameMs = _sumFrameTotal.inMicroseconds / frameCount / 1000;
    final avgBuildMs = _sumBuild.inMicroseconds / frameCount / 1000;
    final avgRasterMs = _sumRaster.inMicroseconds / frameCount / 1000;

    return {
      'frameCount': frameCount,
      'jankCount': _jankFrameCount,
      'avgFrameMs': _round(avgFrameMs),
      'avgBuildMs': _round(avgBuildMs),
      'avgRasterMs': _round(avgRasterMs),
      'worstFrameMs': _round(_worstFrame.inMicroseconds / 1000),
    };
  }

  void _emit({
    required String operation,
    required CanvasState canvasState,
    Map<String, Object?> metrics = const {},
  }) {
    if (!_enabled) return;

    final payload = {
      'type': 'canvas_perf',
      'timestamp': DateTime.now().toIso8601String(),
      'operation': operation,
      'zoom': _round(canvasState.zoom),
      'viewportOffsetX': _round(canvasState.viewportOffset.dx),
      'viewportOffsetY': _round(canvasState.viewportOffset.dy),
      'selectedCount': canvasState.selectedShapeIds.length,
      'shapeCount': canvasState.shapeList.length,
      'metrics': metrics,
    };

    // Use direct print so diagnostics work in debug/profile/release when
    // VIO_CANVAS_PERF_DIAGNOSTICS=true, independent of VioLogger debug gating.
    // ignore: avoid_print
    print('CANVAS_PERF ${jsonEncode(payload)}');
  }

  double _round(num value) => double.parse(value.toStringAsFixed(3));
}
