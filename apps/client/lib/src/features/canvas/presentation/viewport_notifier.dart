import 'package:flutter/widgets.dart';
import 'package:vio_core/vio_core.dart';

/// Lightweight notifier for viewport state (zoom, offset, viewMatrix).
///
/// During pan/zoom gestures, the gesture handler updates this notifier
/// **directly** via [applyPan] / [applyZoom] / [applyTransform] — bypassing
/// the BLoC entirely for zero-overhead repaints. The painter listens to this
/// as its `repaint` listenable.
///
/// At gesture end the authoritative state is synced back to the BLoC with
/// a single `ViewportSynced` event.
class ViewportNotifier extends ChangeNotifier {
  double _zoom = 1.0;
  Offset _offset = Offset.zero;
  Size _size = const Size(800, 600);
  Matrix2D _viewMatrix = Matrix2D.identity;

  double get zoom => _zoom;
  Offset get offset => _offset;
  Size get size => _size;
  Matrix2D get viewMatrix => _viewMatrix;

  /// Full update (used when BLoC emits a new viewport state).
  void update({
    required double zoom,
    required Offset offset,
    required Size size,
    required Matrix2D viewMatrix,
  }) {
    if (_zoom == zoom &&
        _offset == offset &&
        _size == size &&
        _viewMatrix == viewMatrix) {
      return;
    }
    _zoom = zoom;
    _offset = offset;
    _size = size;
    _viewMatrix = viewMatrix;
    notifyListeners();
  }

  /// Apply a pan delta directly (no BLoC round-trip).
  void applyPan(double dx, double dy) {
    _offset = Offset(_offset.dx + dx, _offset.dy + dy);
    _recomputeMatrix();
    notifyListeners();
  }

  /// Apply focal-point zoom directly (no BLoC round-trip).
  void applyZoom(double scaleFactor, double focalX, double focalY) {
    final newZoom = (_zoom * scaleFactor).clamp(0.01, 64.0);
    final zoomRatio = newZoom / _zoom;
    _offset = Offset(
      focalX - (focalX - _offset.dx) * zoomRatio,
      focalY - (focalY - _offset.dy) * zoomRatio,
    );
    _zoom = newZoom;
    _recomputeMatrix();
    notifyListeners();
  }

  /// Apply combined pan + zoom directly (no BLoC round-trip).
  void applyTransform({
    required double dx,
    required double dy,
    required double scaleFactor,
    required double focalX,
    required double focalY,
  }) {
    // Zoom first (focal-point centered), then pan.
    final hasMeaningfulZoom = (scaleFactor - 1.0).abs() > 0.0001;
    if (hasMeaningfulZoom) {
      final newZoom = (_zoom * scaleFactor).clamp(0.01, 64.0);
      final zoomRatio = newZoom / _zoom;
      _offset = Offset(
        focalX - (focalX - _offset.dx) * zoomRatio,
        focalY - (focalY - _offset.dy) * zoomRatio,
      );
      _zoom = newZoom;
    }
    if (dx != 0.0 || dy != 0.0) {
      _offset = Offset(_offset.dx + dx, _offset.dy + dy);
    }
    _recomputeMatrix();
    notifyListeners();
  }

  void _recomputeMatrix() {
    _viewMatrix = Matrix2D.identity
        .translated(_offset.dx, _offset.dy)
        .scaled(_zoom, _zoom);
  }
}
