import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:vio_core/vio_core.dart';

class CanvasInputLayer extends StatelessWidget {
  const CanvasInputLayer({
    required this.cursor,
    required this.onHover,
    required this.onExit,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.onPointerSignal,
    required this.onPointerPanZoomStart,
    required this.onPointerPanZoomUpdate,
    required this.onPointerPanZoomEnd,
    required this.onAssetAccept,
    required this.child,
    super.key,
  });

  final MouseCursor cursor;
  final VoidCallback onExit;
  final ValueChanged<PointerHoverEvent> onHover;
  final ValueChanged<PointerDownEvent> onPointerDown;
  final ValueChanged<PointerMoveEvent> onPointerMove;
  final ValueChanged<PointerUpEvent> onPointerUp;
  final ValueChanged<PointerSignalEvent> onPointerSignal;
  final ValueChanged<PointerPanZoomStartEvent> onPointerPanZoomStart;
  final ValueChanged<PointerPanZoomUpdateEvent> onPointerPanZoomUpdate;
  final ValueChanged<PointerPanZoomEndEvent> onPointerPanZoomEnd;
  final ValueChanged<DragTargetDetails<ProjectAsset>> onAssetAccept;
  final Widget child;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: cursor,
        onHover: onHover,
        onExit: (_) => onExit(),
        child: Listener(
          onPointerDown: onPointerDown,
          onPointerMove: onPointerMove,
          onPointerUp: onPointerUp,
          onPointerSignal: onPointerSignal,
          onPointerPanZoomStart: onPointerPanZoomStart,
          onPointerPanZoomUpdate: onPointerPanZoomUpdate,
          onPointerPanZoomEnd: onPointerPanZoomEnd,
          child: DragTarget<ProjectAsset>(
            onAcceptWithDetails: onAssetAccept,
            builder: (context, candidateData, rejectedData) => child,
          ),
        ),
      );
}
