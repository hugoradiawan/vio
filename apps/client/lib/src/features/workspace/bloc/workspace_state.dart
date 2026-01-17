part of 'workspace_bloc.dart';

/// Available drawing/editing tools
enum CanvasTool {
  /// Selection/move tool (V)
  select,

  /// Direct selection for path points (A)
  directSelect,

  /// Rectangle shape tool (R)
  rectangle,

  /// Ellipse shape tool (O)
  ellipse,

  /// Line/path tool (P)
  path,

  /// Text tool (T)
  text,

  /// Frame/artboard tool (F)
  frame,

  /// Hand tool for panning (H or Space)
  hand,

  /// Zoom tool (Z)
  zoom,

  /// Comment tool (C)
  comment,
}

/// Workspace loading status
enum WorkspaceStatus {
  initial,
  loading,
  ready,
  error,
}

/// Represents the complete state of the workspace UI
class WorkspaceState extends Equatable {
  const WorkspaceState({
    this.status = WorkspaceStatus.initial,
    this.activeTool = CanvasTool.select,
    this.isLeftPanelVisible = true,
    this.isRightPanelVisible = true,
    this.zoom = 1.0,
    this.showGrid = false,
    this.snapToGrid = true,
    this.showRulers = true,
    this.gridSize = 8.0,
    this.frameToolPresetId,
    this.isLayersSearchOpen = false,
    this.layersSearchQuery = '',
    this.errorMessage,
  });

  /// Current loading/ready status
  final WorkspaceStatus status;

  /// Currently active tool
  final CanvasTool activeTool;

  /// Whether the left panel (layers, assets) is visible
  final bool isLeftPanelVisible;

  /// Whether the right panel (properties, design) is visible
  final bool isRightPanelVisible;

  /// Current zoom level (1.0 = 100%)
  final double zoom;

  /// Whether to show the grid overlay
  final bool showGrid;

  /// Whether shapes snap to grid
  final bool snapToGrid;

  /// Whether to show rulers
  final bool showRulers;

  /// Grid cell size in logical pixels
  final double gridSize;

  /// Default frame preset id used by the Frame tool (null = custom).
  final String? frameToolPresetId;

  /// Whether the Layers panel search UI is open.
  final bool isLayersSearchOpen;

  /// Current search query for filtering the layers tree.
  final String layersSearchQuery;

  /// Error message if status is error
  final String? errorMessage;

  /// Zoom as percentage string
  String get zoomPercentage => '${(zoom * 100).round()}%';

  /// Whether the workspace is ready for interaction
  bool get isReady => status == WorkspaceStatus.ready;

  WorkspaceState copyWith({
    WorkspaceStatus? status,
    CanvasTool? activeTool,
    bool? isLeftPanelVisible,
    bool? isRightPanelVisible,
    double? zoom,
    bool? showGrid,
    bool? snapToGrid,
    bool? showRulers,
    double? gridSize,
    String? frameToolPresetId,
    bool? isLayersSearchOpen,
    String? layersSearchQuery,
    String? errorMessage,
  }) {
    return WorkspaceState(
      status: status ?? this.status,
      activeTool: activeTool ?? this.activeTool,
      isLeftPanelVisible: isLeftPanelVisible ?? this.isLeftPanelVisible,
      isRightPanelVisible: isRightPanelVisible ?? this.isRightPanelVisible,
      zoom: zoom ?? this.zoom,
      showGrid: showGrid ?? this.showGrid,
      snapToGrid: snapToGrid ?? this.snapToGrid,
      showRulers: showRulers ?? this.showRulers,
      gridSize: gridSize ?? this.gridSize,
      frameToolPresetId: frameToolPresetId ?? this.frameToolPresetId,
      isLayersSearchOpen: isLayersSearchOpen ?? this.isLayersSearchOpen,
      layersSearchQuery: layersSearchQuery ?? this.layersSearchQuery,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        activeTool,
        isLeftPanelVisible,
        isRightPanelVisible,
        zoom,
        showGrid,
        snapToGrid,
        showRulers,
        gridSize,
        frameToolPresetId,
        isLayersSearchOpen,
        layersSearchQuery,
        errorMessage,
      ];
}
