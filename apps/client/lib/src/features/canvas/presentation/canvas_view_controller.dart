part of 'canvas_view.dart';

mixin _CanvasViewController on State<CanvasView> {
  void _resetBufferedPanZoom(Offset focalPoint) {
    final state = this as _CanvasViewState;
    state._bufferedPanZoomDelta = Offset.zero;
    state._bufferedPanZoomScale = 1.0;
    state._bufferedPanZoomFocal = focalPoint;
    state._lastPanZoomFlushTimestamp =
        DateTime.now().millisecondsSinceEpoch;
  }

  void _bufferPanZoomViewportUpdate(
    BuildContext context, {
    required double scaleFactor,
    required Offset panDelta,
    required Offset focalPoint,
  }) {
    final state = this as _CanvasViewState;
    final zoomDrift = (scaleFactor - 1.0).abs();

    if (zoomDrift >= _CanvasViewState._panZoomScaleDriftEpsilon) {
      state._bufferedPanZoomScale *= scaleFactor;
    }
    if (panDelta != Offset.zero) {
      state._bufferedPanZoomDelta += panDelta;
    }
    state._bufferedPanZoomFocal = focalPoint;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - state._lastPanZoomFlushTimestamp >=
        _CanvasViewState._panZoomFlushThrottleMs) {
      _flushBufferedPanZoom(context);
    }
  }

  void _flushBufferedPanZoom(BuildContext context, {bool force = false}) {
    final state = this as _CanvasViewState;
    final canvasBloc = context.read<CanvasBloc>();

    final scale = state._bufferedPanZoomScale;
    final hasMeaningfulZoom =
        (scale - 1.0).abs() >= _CanvasViewState._panZoomScaleDriftEpsilon;
    if (hasMeaningfulZoom) {
      canvasBloc.add(
        ViewportZoomed(
          scaleFactor: scale,
          focalX: state._bufferedPanZoomFocal.dx,
          focalY: state._bufferedPanZoomFocal.dy,
        ),
      );
      state._bufferedPanZoomScale = 1.0;
    }

    final panDelta = state._bufferedPanZoomDelta;
    if (panDelta != Offset.zero) {
      canvasBloc.add(
        ViewportPanned(
          deltaX: panDelta.dx,
          deltaY: panDelta.dy,
        ),
      );
      state._bufferedPanZoomDelta = Offset.zero;
    }

    state._lastPanZoomFlushTimestamp =
        DateTime.now().millisecondsSinceEpoch;
  }

  void _setViewportInteractionActive({Duration? holdFor}) {
    final state = this as _CanvasViewState;

    state._viewportInteractionTimer?.cancel();
    if (!state._isViewportInteractionActive) {
      state.setState(() {
        state._isViewportInteractionActive = true;
      });
    }

    if (holdFor != null) {
      state._viewportInteractionTimer = Timer(holdFor, () {
        if (!mounted) return;
        if (state._isPanning) return;

        _flushBufferedPanZoom(context, force: true);

        state.setState(() {
          state._isViewportInteractionActive = false;
        });
      });
    }
  }

  void _setViewportInteractionInactive() {
    final state = this as _CanvasViewState;
    state._viewportInteractionTimer?.cancel();
    _flushBufferedPanZoom(context, force: true);
    if (!state._isViewportInteractionActive) {
      return;
    }

    state.setState(() {
      state._isViewportInteractionActive = false;
    });
  }

  void _onTextControllerChanged() {
    final state = this as _CanvasViewState;
    final shapeId = state._editingTextShapeId;
    if (shapeId == null) {
      return;
    }

    state._textLayoutDebounce?.cancel();
    state._textLayoutDebounce = Timer(const Duration(milliseconds: 50), () {
      if (!mounted) return;

      final bloc = context.read<CanvasBloc>();
      final shape = bloc.state.shapes[shapeId];
      if (shape is! TextShape) return;

      final (measuredWidth, measuredHeight) =
          _measureText(state._textController.text, shape);

      final width = measuredWidth;
      final height = measuredHeight;

      const eps = 0.5;
      if (state._lastSentTextWidth != null &&
          state._lastSentTextHeight != null &&
          (width - state._lastSentTextWidth!).abs() < eps &&
          (height - state._lastSentTextHeight!).abs() < eps) {
        return;
      }

      state._lastSentTextWidth = width;
      state._lastSentTextHeight = height;

      bloc.add(
        TextEditLayoutChanged(
          shapeId: shapeId,
          width: width,
          height: height,
        ),
      );
    });
  }

  bool _handleKeyboardEvent(KeyEvent event) {
    final state = this as _CanvasViewState;
    final primaryFocus = FocusManager.instance.primaryFocus;
    final isTextFieldFocused = primaryFocus?.context?.widget is EditableText ||
        primaryFocus?.context?.findAncestorWidgetOfExactType<EditableText>() !=
            null;

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        if (isTextFieldFocused || state._editingTextShapeId != null) {
          return false;
        }

        state.setState(() => state._isSpacePressed = true);
        return true;
      }

      final isCtrlPressed = isPlatformModifierPressed();
      final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

      if (isCtrlPressed) {
        final bloc = context.read<CanvasBloc>();

        switch (event.logicalKey) {
          case LogicalKeyboardKey.keyC:
            bloc.add(const CopySelected());
            return true;
          case LogicalKeyboardKey.keyX:
            bloc.add(const CutSelected());
            return true;
          case LogicalKeyboardKey.keyV:
            bloc.add(const PasteShapes());
            return true;
          case LogicalKeyboardKey.keyD:
            bloc.add(const DuplicateSelected());
            return true;
          case LogicalKeyboardKey.keyZ:
            if (isShiftPressed) {
              bloc.add(const Redo());
            } else {
              bloc.add(const Undo());
            }
            return true;
          case LogicalKeyboardKey.keyY:
            bloc.add(const Redo());
            return true;
          default:
            break;
        }
      } else {
        switch (event.logicalKey) {
          case LogicalKeyboardKey.delete:
          case LogicalKeyboardKey.backspace:
            if (!isTextFieldFocused) {
              context.read<CanvasBloc>().add(const DeleteSelected());
              return true;
            }
            return false;
          case LogicalKeyboardKey.escape:
            if (isTextFieldFocused && state._editingTextShapeId != null) {
              _cancelTextEdit();
              return true;
            }
            context.read<CanvasBloc>().add(const SelectionCleared());
            return true;
          default:
            break;
        }
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        if (isTextFieldFocused || state._editingTextShapeId != null) {
          return false;
        }

        state.setState(() {
          state._isSpacePressed = false;
          state._isPanning = false;
        });
        return true;
      }
    }
    return false;
  }

  MouseCursor _getCursor(CanvasTool tool, CanvasState canvasState) {
    final state = this as _CanvasViewState;
    if (state._isSpacePressed || state._isPanning) {
      return SystemMouseCursors.grab;
    }

    bool supportsSelectionCursor(CanvasTool activeTool) {
      return activeTool == CanvasTool.select ||
          activeTool == CanvasTool.directSelect;
    }

    if (supportsSelectionCursor(tool)) {
      if (canvasState.interactionMode == InteractionMode.rotating) {
        return SystemMouseCursors.grab;
      }

      if (canvasState.interactionMode == InteractionMode.resizing ||
          canvasState.interactionMode == InteractionMode.rotating) {
        final activeCursor =
            _cursorForSelectionKind(canvasState.selectionCursorKind);
        if (activeCursor != null) {
          return activeCursor;
        }
      }

      final selectionCursor = _cursorForSelectionKind(
        canvasState.selectionCursorKind,
      );
      if (selectionCursor != null) {
        return selectionCursor;
      }
    }

    return switch (tool) {
      CanvasTool.select => SystemMouseCursors.basic,
      CanvasTool.directSelect => SystemMouseCursors.basic,
      CanvasTool.rectangle => SystemMouseCursors.precise,
      CanvasTool.ellipse => SystemMouseCursors.precise,
      CanvasTool.path => SystemMouseCursors.precise,
      CanvasTool.text => SystemMouseCursors.text,
      CanvasTool.frame => SystemMouseCursors.precise,
      CanvasTool.hand => SystemMouseCursors.grab,
      CanvasTool.zoom => SystemMouseCursors.basic,
      CanvasTool.comment => SystemMouseCursors.basic,
    };
  }

  MouseCursor? _cursorForSelectionKind(SelectionCursorKind kind) {
    final isMacDesktop =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

    return switch (kind) {
      SelectionCursorKind.none => null,
      SelectionCursorKind.resizeHorizontal =>
        SystemMouseCursors.resizeLeftRight,
      SelectionCursorKind.resizeVertical => SystemMouseCursors.resizeUpDown,
      SelectionCursorKind.resizeDiagonalPrimary => isMacDesktop
          ? SystemMouseCursors.resizeLeftRight
          : SystemMouseCursors.resizeUpLeftDownRight,
      SelectionCursorKind.resizeDiagonalSecondary => isMacDesktop
          ? SystemMouseCursors.resizeUpDown
          : SystemMouseCursors.resizeUpRightDownLeft,
      SelectionCursorKind.rotate => SystemMouseCursors.grab,
    };
  }

  void _handlePointerDown(
    BuildContext context,
    PointerDownEvent event,
    WorkspaceState workspaceState,
  ) {
    final state = this as _CanvasViewState;
    final editingId = state._editingTextShapeId;
    if (editingId != null) {
      final canvasState = context.read<CanvasBloc>().state;
      final shape = canvasState.shapes[editingId];
      if (shape is TextShape) {
        final editorRect = _getTextEditorScreenRect(shape, canvasState);
        if (editorRect.contains(event.localPosition)) {
          return;
        }
      }

      _commitTextEdit(shapeId: editingId);
      state._suppressBlurCommitForShapeId = editingId;
      state._textFocusNode.unfocus();
    }

    final isRightClick = (event.buttons & kSecondaryButton) != 0;
    if (isRightClick) {
      if (workspaceState.showRulers) {
        const rulerThickness = 20.0;
        final inRulerStrip = event.localPosition.dx <= rulerThickness ||
            event.localPosition.dy <= rulerThickness;
        if (inRulerStrip) {
          unawaited(
            _showRulerContextMenu(
              context: context,
              globalPosition: event.position,
            ),
          );
          return;
        }
      }

      final canvasBloc = context.read<CanvasBloc>();
      final canvasState = canvasBloc.state;

      final canvasPoint = canvasState.screenToCanvas(
        Size(event.localPosition.dx, event.localPosition.dy),
      );
      final hitShape = HitTest.findTopShapeAtPoint(
        canvasPoint,
        canvasState.shapeList,
      );

      final effectiveSelectionIds = hitShape == null
          ? const <String>[]
          : (canvasState.selectedShapeIds.contains(hitShape.id)
              ? canvasState.selectedShapeIds
              : <String>[hitShape.id]);

      if (hitShape == null) {
        canvasBloc.add(const SelectionCleared());
      } else if (!canvasState.selectedShapeIds.contains(hitShape.id)) {
        canvasBloc.add(ShapesSelected([hitShape.id]));
      }

      unawaited(
        _showCanvasContextMenu(
          context: context,
          globalPosition: event.position,
          canvasState: canvasState,
          selectionIds: effectiveSelectionIds,
        ),
      );
      return;
    }

    if (event.buttons == kMiddleMouseButton ||
        (state._isSpacePressed && event.buttons == kPrimaryButton) ||
        workspaceState.activeTool == CanvasTool.hand) {
      _setViewportInteractionActive();
      state._perfDiagnostics.onDragPanStart(
        context.read<CanvasBloc>().state,
        source: 'pointer_drag',
      );
      state.setState(() {
        state._isPanning = true;
        state._lastPanPosition = event.localPosition;
      });
      return;
    }

    if (event.buttons == kPrimaryButton &&
        (workspaceState.activeTool == CanvasTool.select ||
            workspaceState.activeTool == CanvasTool.directSelect)) {
      final canvasState = context.read<CanvasBloc>().state;
      final canvasPoint = canvasState.screenToCanvas(
        Size(event.localPosition.dx, event.localPosition.dy),
      );
      final hitShape = HitTest.findTopShapeAtPoint(
        canvasPoint,
        canvasState.shapeList,
      );

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final withinTime = (nowMs - state._lastPrimaryClickMs) <=
          _CanvasViewState._doubleClickThresholdMs;
      final withinDistance = state._lastPrimaryClickPosition == null
          ? false
          : (event.localPosition - state._lastPrimaryClickPosition!).distance <=
              _CanvasViewState._doubleClickMaxDistancePx;
      final sameShape =
          hitShape != null && hitShape.id == state._lastPrimaryClickShapeId;

      if (withinTime && withinDistance && sameShape) {
        context.read<CanvasBloc>().add(
              CanvasDoubleClicked(
                x: event.localPosition.dx,
                y: event.localPosition.dy,
              ),
            );

        state._lastPrimaryClickMs = 0;
        state._lastPrimaryClickPosition = null;
        state._lastPrimaryClickShapeId = null;
        return;
      }

      state._lastPrimaryClickMs = nowMs;
      state._lastPrimaryClickPosition = event.localPosition;
      state._lastPrimaryClickShapeId = hitShape?.id;
    }

    final tool = switch (workspaceState.activeTool) {
      CanvasTool.rectangle => CanvasPointerTool.drawRectangle,
      CanvasTool.ellipse => CanvasPointerTool.drawEllipse,
      CanvasTool.frame => CanvasPointerTool.drawFrame,
      CanvasTool.text => CanvasPointerTool.drawText,
      CanvasTool.directSelect => CanvasPointerTool.directSelect,
      _ => CanvasPointerTool.select,
    };

    final preset = tool == CanvasPointerTool.drawFrame
        ? framePresetById(workspaceState.frameToolPresetId)
        : null;

    context.read<CanvasBloc>().add(
          PointerDown(
            x: event.localPosition.dx,
            y: event.localPosition.dy,
            button: event.buttons,
            shiftPressed: HardwareKeyboard.instance.isShiftPressed,
            tool: tool,
            initialWidth: preset?.width,
            initialHeight: preset?.height,
          ),
        );
  }

  Future<void> _showCanvasContextMenu({
    required BuildContext context,
    required Offset globalPosition,
    required CanvasState canvasState,
    required List<String> selectionIds,
  }) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    final selectedShapes = selectionIds
        .map((id) => canvasState.shapes[id])
        .whereType<Shape>()
        .toList(growable: false);

    final hasSelection = selectedShapes.isNotEmpty;
    final hasClipboard = canvasState.clipboardShapes.isNotEmpty;
    final hasUnlockedSelection = selectedShapes.any((s) => !s.blocked);

    final canGroup = () {
      if (selectedShapes.length < 2) return false;
      final groupable = selectedShapes
          .where((s) => s is! FrameShape)
          .where((s) => !s.blocked)
          .toList(growable: false);
      if (groupable.length < 2) return false;
      final frameIds = groupable.map((s) => s.frameId).toSet();
      return frameIds.length <= 1;
    }();

    final canUngroup = selectedShapes.any((s) => s is GroupShape && !s.blocked);

    const menuItemHeight = 34.0;
    const menuItemPadding = EdgeInsets.symmetric(horizontal: 12);
    const menuTextStyle = TextStyle(fontSize: 13);

    final action = await showMenu<_CanvasContextAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: <PopupMenuEntry<_CanvasContextAction>>[
        PopupMenuItem(
          value: _CanvasContextAction.cut,
          enabled: hasSelection && hasUnlockedSelection,
          height: menuItemHeight,
          padding: menuItemPadding,
          textStyle: menuTextStyle,
          child: const Text('Cut'),
        ),
        PopupMenuItem(
          value: _CanvasContextAction.copy,
          enabled: hasSelection,
          height: menuItemHeight,
          padding: menuItemPadding,
          textStyle: menuTextStyle,
          child: const Text('Copy'),
        ),
        PopupMenuItem(
          value: _CanvasContextAction.paste,
          enabled: hasClipboard,
          height: menuItemHeight,
          padding: menuItemPadding,
          textStyle: menuTextStyle,
          child: const Text('Paste'),
        ),
        const PopupMenuDivider(height: 8),
        PopupMenuItem(
          value: _CanvasContextAction.group,
          enabled: canGroup,
          height: menuItemHeight,
          padding: menuItemPadding,
          textStyle: menuTextStyle,
          child: const Text('Group'),
        ),
        PopupMenuItem(
          value: _CanvasContextAction.ungroup,
          enabled: canUngroup,
          height: menuItemHeight,
          padding: menuItemPadding,
          textStyle: menuTextStyle,
          child: const Text('Ungroup'),
        ),
        const PopupMenuDivider(height: 8),
        PopupMenuItem(
          value: _CanvasContextAction.bringToFront,
          enabled: hasSelection && hasUnlockedSelection,
          height: menuItemHeight,
          padding: menuItemPadding,
          textStyle: menuTextStyle,
          child: const Text('Bring to front'),
        ),
        PopupMenuItem(
          value: _CanvasContextAction.sendToBack,
          enabled: hasSelection && hasUnlockedSelection,
          height: menuItemHeight,
          padding: menuItemPadding,
          textStyle: menuTextStyle,
          child: const Text('Send to back'),
        ),
      ],
    );

    if (action == null || !context.mounted) return;

    final bloc = context.read<CanvasBloc>();
    switch (action) {
      case _CanvasContextAction.cut:
        bloc.add(const CutSelected());
        break;
      case _CanvasContextAction.copy:
        bloc.add(const CopySelected());
        break;
      case _CanvasContextAction.paste:
        bloc.add(const PasteShapes());
        break;
      case _CanvasContextAction.group:
        bloc.add(const CreateGroupFromSelection());
        break;
      case _CanvasContextAction.ungroup:
        bloc.add(const UngroupSelected());
        break;
      case _CanvasContextAction.bringToFront:
        bloc.add(const BringToFrontSelected());
        break;
      case _CanvasContextAction.sendToBack:
        bloc.add(const SendToBackSelected());
        break;
    }
  }

  Future<void> _showRulerContextMenu({
    required BuildContext context,
    required Offset globalPosition,
  }) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    const menuItemHeight = 34.0;
    const menuItemPadding = EdgeInsets.symmetric(horizontal: 12);
    const menuTextStyle = TextStyle(fontSize: 13);

    final action = await showMenu<_RulerContextAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: const <PopupMenuEntry<_RulerContextAction>>[
        PopupMenuItem(
          value: _RulerContextAction.hideRulers,
          height: menuItemHeight,
          padding: menuItemPadding,
          textStyle: menuTextStyle,
          child: Text('Hide rulers'),
        ),
      ],
    );

    if (action == null || !context.mounted) return;

    switch (action) {
      case _RulerContextAction.hideRulers:
        context.read<WorkspaceBloc>().add(const RulersToggled());
        break;
    }
  }

  void _handlePointerMove(
    BuildContext context,
    PointerMoveEvent event,
    WorkspaceState workspaceState,
  ) {
    final state = this as _CanvasViewState;
    if (state._isPanning && state._lastPanPosition != null) {
      _setViewportInteractionActive();
      final delta = event.localPosition - state._lastPanPosition!;
      state._perfDiagnostics.onDragPanUpdate(
        delta,
        context.read<CanvasBloc>().state,
      );
      context.read<CanvasBloc>().add(
            ViewportPanned(
              deltaX: delta.dx,
              deltaY: delta.dy,
            ),
          );
      state._lastPanPosition = event.localPosition;
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - state._lastMoveTimestamp < _CanvasViewState._throttleMs) {
      return;
    }
    state._lastMoveTimestamp = now;

    context.read<CanvasBloc>().add(
          PointerMove(
            x: event.localPosition.dx,
            y: event.localPosition.dy,
            shiftPressed: HardwareKeyboard.instance.isShiftPressed,
          ),
        );
  }

  void _handlePointerUp(BuildContext context, PointerUpEvent event) {
    final state = this as _CanvasViewState;
    if (state._isPanning) {
      state._perfDiagnostics.onDragPanEnd(context.read<CanvasBloc>().state);
      state.setState(() {
        state._isPanning = false;
        state._lastPanPosition = null;
      });
      _setViewportInteractionInactive();
      return;
    }

    context.read<CanvasBloc>().add(
          PointerUp(
            x: event.localPosition.dx,
            y: event.localPosition.dy,
          ),
        );
  }

  void _handlePointerHover(
    BuildContext context,
    PointerHoverEvent event,
    WorkspaceState workspaceState,
  ) {
    final state = this as _CanvasViewState;
    if (state._isViewportInteractionActive || state._isPanning) {
      return;
    }

    context.read<CanvasBloc>().add(
          PointerMove(
            x: event.localPosition.dx,
            y: event.localPosition.dy,
          ),
        );
  }

  void _handlePointerExit(BuildContext context) {
    context.read<CanvasBloc>().add(const CanvasPointerExited());
  }

  void _handleAssetDrop(
    BuildContext context,
    DragTargetDetails<ProjectAsset> details,
    CanvasState canvasState,
  ) {
    final asset = details.data;
    final renderBox = context.findRenderObject() as RenderBox;
    final localOffset = renderBox.globalToLocal(details.offset);

    final canvasPoint = canvasState.screenToCanvas(
      Size(localOffset.dx, localOffset.dy),
    );

    final newId = const Uuid().v4();

    Shape shape;
    if (asset.isSvg) {
      final sw = (asset.width > 0 ? asset.width : 200).toDouble();
      final sh = (asset.height > 0 ? asset.height : 200).toDouble();
      shape = SvgShape(
        id: newId,
        name: asset.name,
        x: canvasPoint.dx - sw / 2,
        y: canvasPoint.dy - sh / 2,
        svgWidth: sw,
        svgHeight: sh,
      );
    } else {
      final w = (asset.width > 0 ? asset.width : 200).toDouble();
      final h = (asset.height > 0 ? asset.height : 200).toDouble();
      shape = ImageShape(
        id: newId,
        name: asset.name,
        x: canvasPoint.dx - w / 2,
        y: canvasPoint.dy - h / 2,
        imageWidth: w,
        imageHeight: h,
        assetId: asset.id,
        originalWidth: w,
        originalHeight: h,
      );
    }

    context.read<CanvasBloc>().add(ShapeAdded(shape));
  }

  void _loadImagesForNewShapes(BuildContext context, CanvasState state) {
    final viewState = this as _CanvasViewState;
    for (final shape in state.shapes.values) {
      if (shape is ImageShape &&
          shape.assetId.isNotEmpty &&
          !ImageCacheService.instance.has(shape.assetId) &&
          !ImageCacheService.instance.isPending(shape.assetId) &&
          !viewState._requestedAssetIds.contains(shape.assetId)) {
        viewState._requestedAssetIds.add(shape.assetId);
        context
            .read<AssetBloc>()
            .add(AssetDataRequested(assetId: shape.assetId));
      }
    }
  }

  Future<void> _handleOsFileDrop(
    BuildContext context,
    DropDoneDetails details,
    Offset? dropPosition,
  ) async {
    final assetBloc = context.read<AssetBloc>();
    final canvasBloc = context.read<CanvasBloc>();
    final projectId = assetBloc.state.projectId;
    if (projectId == null || projectId.isEmpty) return;

    const allowedExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'svg'};
    const mimeMap = {
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'svg': 'image/svg+xml',
    };

    final canvasState = canvasBloc.state;
    double canvasX;
    double canvasY;
    if (dropPosition != null) {
      final canvasPoint = canvasState.screenToCanvas(
        Size(dropPosition.dx, dropPosition.dy),
      );
      canvasX = canvasPoint.dx;
      canvasY = canvasPoint.dy;
    } else {
      canvasX =
          (canvasState.viewportSize.width / 2 - canvasState.viewportOffset.dx) /
              canvasState.zoom;
      canvasY = (canvasState.viewportSize.height / 2 -
              canvasState.viewportOffset.dy) /
          canvasState.zoom;
    }

    var offsetIndex = 0;
    for (final xFile in details.files) {
      final name = xFile.name;
      final ext = name.split('.').last.toLowerCase();

      if (!allowedExtensions.contains(ext)) continue;

      final bytes = await xFile.readAsBytes();
      if (bytes.isEmpty) continue;

      final mimeType = mimeMap[ext] ?? 'application/octet-stream';

      assetBloc.add(
        AssetUploaded(
          projectId: projectId,
          name: name,
          mimeType: mimeType,
          data: bytes,
          createShapeOnCanvas: true,
          canvasX: canvasX + offsetIndex * 20,
          canvasY: canvasY + offsetIndex * 20,
        ),
      );
      offsetIndex++;
    }
  }

  void _handlePointerSignal(BuildContext context, PointerSignalEvent event) {
    final state = this as _CanvasViewState;

    if (event is PointerScrollEvent) {
      final canvasState = context.read<CanvasBloc>().state;
      final isZoomGesture = isPlatformModifierPressed();
      final isShiftScroll = HardwareKeyboard.instance.isShiftPressed;

      if (isZoomGesture) {
        const zoomSensitivity = 0.002;
        final scaleFactor = 1.0 - (event.scrollDelta.dy * zoomSensitivity);
        final clampedScale = scaleFactor.clamp(0.5, 2.0);
        _setViewportInteractionActive(
          holdFor: const Duration(milliseconds: 180),
        );
        state._perfDiagnostics.onWheelZoom(
          scaleFactor: clampedScale,
          canvasState: canvasState,
        );
        _bufferPanZoomViewportUpdate(
          context,
          scaleFactor: clampedScale,
          panDelta: Offset.zero,
          focalPoint: event.localPosition,
        );
      } else {
        final deltaX = isShiftScroll
            ? -(event.scrollDelta.dx != 0
                ? event.scrollDelta.dx
                : event.scrollDelta.dy)
            : -event.scrollDelta.dx;
        final deltaY = isShiftScroll ? 0.0 : -event.scrollDelta.dy;
        _setViewportInteractionActive(
          holdFor: const Duration(milliseconds: 180),
        );
        state._perfDiagnostics.onWheelPan(
          deltaX: deltaX,
          deltaY: deltaY,
          canvasState: canvasState,
        );
        _bufferPanZoomViewportUpdate(
          context,
          scaleFactor: 1.0,
          panDelta: Offset(deltaX, deltaY),
          focalPoint: event.localPosition,
        );
      }
    } else if (event is PointerScaleEvent) {
      final scaleDrift = (event.scale - 1.0).abs();
      if (scaleDrift < _CanvasViewState._pointerScaleGestureEpsilon) {
        return;
      }

      _setViewportInteractionActive(
        holdFor: const Duration(milliseconds: 180),
      );
      state._perfDiagnostics.onWheelZoom(
        scaleFactor: event.scale,
        canvasState: context.read<CanvasBloc>().state,
      );
      _bufferPanZoomViewportUpdate(
        context,
        scaleFactor: event.scale,
        panDelta: Offset.zero,
        focalPoint: event.localPosition,
      );
    }
  }

  void _commitTextEdit({String? shapeId}) {
    final state = this as _CanvasViewState;
    shapeId ??= state._editingTextShapeId;
    if (shapeId == null) return;

    final bloc = context.read<CanvasBloc>();
    final shape = bloc.state.shapes[shapeId];
    if (shape is! TextShape) {
      bloc.add(TextEditCanceled(shapeId: shapeId));
      return;
    }

    final text = state._textController.text;
    final (width, height) = _measureText(text, shape);

    bloc.add(
      TextEditCommitted(
        shapeId: shapeId,
        text: text,
        width: width,
        height: height,
      ),
    );
  }

  Rect _getTextEditorScreenRect(TextShape shape, CanvasState canvasState) {
    final bounds = shape.bounds;
    final anchorCanvas = shape.transformPoint(bounds.topLeft);
    final anchorScreen = canvasState.canvasToScreen(anchorCanvas);

    final canvasWidth = bounds.width <= 1 ? 200.0 : bounds.width;
    final canvasHeight = bounds.height <= 1 ? 24.0 : bounds.height;

    final screenWidth = canvasWidth * canvasState.zoom;
    final screenHeight = canvasHeight * canvasState.zoom;

    return Rect.fromLTWH(
      anchorScreen.dx,
      anchorScreen.dy,
      screenWidth,
      screenHeight,
    );
  }

  void _cancelTextEdit() {
    final state = this as _CanvasViewState;
    final shapeId = state._editingTextShapeId;
    if (shapeId == null) return;

    state._suppressBlurCommitForShapeId = shapeId;
    state._textFocusNode.unfocus();
    context.read<CanvasBloc>().add(TextEditCanceled(shapeId: shapeId));
  }

  (double, double) _measureText(String text, TextShape shape) {
    if (text.trim().isEmpty) {
      return (1, 1);
    }

    FontWeight? fontWeight;
    final weightValue = shape.fontWeight;
    if (weightValue != null) {
      fontWeight = FontWeight.values.firstWhere(
        (w) => w.value == weightValue,
        orElse: () => FontWeight.w400,
      );
    }

    final letterSpacing = shape.letterSpacingPercent == 0
        ? null
        : shape.fontSize * (shape.letterSpacingPercent / 100.0);

    final baseStyle = TextStyle(
      fontSize: shape.fontSize,
      fontWeight: fontWeight,
      height: shape.lineHeight,
      letterSpacing: letterSpacing,
    );

    TextStyle resolveFontStyle() {
      final family = shape.fontFamily;
      if (family == null || family.isEmpty) {
        return baseStyle;
      }
      try {
        return GoogleFonts.getFont(family, textStyle: baseStyle);
      } catch (_) {
        return baseStyle.copyWith(fontFamily: family);
      }
    }

    final wrapWidth = (shape.textWidth <= 1 ? 200.0 : shape.textWidth)
        .clamp(1.0, double.infinity);

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: resolveFontStyle(),
      ),
      textAlign: shape.textAlign,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: wrapWidth, maxWidth: wrapWidth);

    final height = (painter.height + 2).clamp(1.0, double.infinity);
    return (wrapWidth, height);
  }

  void _relayoutEditingTextAfterFontLoad({
    required String shapeId,
    required TextShape shape,
  }) {
    final state = this as _CanvasViewState;
    final family = shape.fontFamily;
    if (family == null || family.isEmpty) return;

    final text = state._textController.text;
    if (text.trim().isEmpty) return;

    Future<void>(() async {
      FontWeight? fontWeight;
      final weightValue = shape.fontWeight;
      if (weightValue != null) {
        fontWeight = FontWeight.values.firstWhere(
          (w) => w.value == weightValue,
          orElse: () => FontWeight.w400,
        );
      }

      final letterSpacing = shape.letterSpacingPercent == 0
          ? null
          : shape.fontSize * (shape.letterSpacingPercent / 100.0);

      final baseStyle = TextStyle(
        fontSize: shape.fontSize,
        fontWeight: fontWeight,
        height: shape.lineHeight,
        letterSpacing: letterSpacing,
      );

      TextStyle resolvedStyle;
      try {
        resolvedStyle = GoogleFonts.getFont(family, textStyle: baseStyle);
      } catch (_) {
        return;
      }

      try {
        await GoogleFonts.pendingFonts([resolvedStyle]);
      } catch (_) {
        return;
      }

      if (!mounted) return;
      if (state._editingTextShapeId != shapeId) return;

      final bloc = context.read<CanvasBloc>();
      final latest = bloc.state.shapes[shapeId];
      if (latest is! TextShape) return;

      final (measuredWidth, measuredHeight) =
          _measureText(state._textController.text, latest);

      bloc.add(
        TextEditLayoutChanged(
          shapeId: shapeId,
          width: measuredWidth,
          height: measuredHeight,
        ),
      );
    });
  }
}
