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

/// Panel width constraints
class PanelConstraints {
  PanelConstraints._();

  /// Left panel constraints
  static const double leftPanelMinWidth = 200.0;
  static const double leftPanelMaxWidth = 400.0;
  static const double leftPanelDefaultWidth = 260.0;

  /// Right panel constraints
  static const double rightPanelMinWidth = 200.0;
  static const double rightPanelMaxWidth = 450.0;
  static const double rightPanelDefaultWidth = 280.0;
}

/// Represents the complete state of the workspace UI
class WorkspaceState extends Equatable {
  const WorkspaceState({
    this.status = WorkspaceStatus.initial,
    this.activeTool = CanvasTool.select,
    this.isLeftPanelVisible = true,
    this.isRightPanelVisible = true,
    this.leftPanelWidth = PanelConstraints.leftPanelDefaultWidth,
    this.rightPanelWidth = PanelConstraints.rightPanelDefaultWidth,
    this.isZenMode = false,
    this.zenPreviousLeftPanelVisible = true,
    this.zenPreviousRightPanelVisible = true,
    this.zenPreviousShowRulers = true,
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

  /// Current width of the left panel in logical pixels
  final double leftPanelWidth;

  /// Current width of the right panel in logical pixels
  final double rightPanelWidth;

  /// Whether "zen mode" is active (panels + rulers hidden).
  final bool isZenMode;

  /// Previous left panel visibility before entering zen mode.
  final bool zenPreviousLeftPanelVisible;

  /// Previous right panel visibility before entering zen mode.
  final bool zenPreviousRightPanelVisible;

  /// Previous rulers visibility before entering zen mode.
  final bool zenPreviousShowRulers;

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
    double? leftPanelWidth,
    double? rightPanelWidth,
    bool? isZenMode,
    bool? zenPreviousLeftPanelVisible,
    bool? zenPreviousRightPanelVisible,
    bool? zenPreviousShowRulers,
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
      leftPanelWidth: leftPanelWidth ?? this.leftPanelWidth,
      rightPanelWidth: rightPanelWidth ?? this.rightPanelWidth,
      isZenMode: isZenMode ?? this.isZenMode,
      zenPreviousLeftPanelVisible:
          zenPreviousLeftPanelVisible ?? this.zenPreviousLeftPanelVisible,
      zenPreviousRightPanelVisible:
          zenPreviousRightPanelVisible ?? this.zenPreviousRightPanelVisible,
      zenPreviousShowRulers:
          zenPreviousShowRulers ?? this.zenPreviousShowRulers,
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
        leftPanelWidth,
        rightPanelWidth,
        isZenMode,
        zenPreviousLeftPanelVisible,
        zenPreviousRightPanelVisible,
        zenPreviousShowRulers,
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
