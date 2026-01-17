part of 'workspace_bloc.dart';

/// Base class for workspace events
sealed class WorkspaceEvent extends Equatable {
  const WorkspaceEvent();

  @override
  List<Object?> get props => [];
}

/// Fired when the workspace is first loaded
class WorkspaceInitialized extends WorkspaceEvent {
  const WorkspaceInitialized();
}

/// Fired when user selects a tool from the toolbar
class ToolSelected extends WorkspaceEvent {
  const ToolSelected(this.tool);

  final CanvasTool tool;

  @override
  List<Object?> get props => [tool];
}

/// Fired when left panel (layers/assets) visibility is toggled
class LeftPanelToggled extends WorkspaceEvent {
  const LeftPanelToggled();
}

/// Fired when right panel (properties) visibility is toggled
class RightPanelToggled extends WorkspaceEvent {
  const RightPanelToggled();
}

/// Fired when zoom level changes
class ZoomChanged extends WorkspaceEvent {
  const ZoomChanged(this.zoom);

  final double zoom;

  @override
  List<Object?> get props => [zoom];
}

/// Fired when grid visibility is toggled
class GridToggled extends WorkspaceEvent {
  const GridToggled();
}

/// Fired when snap to grid is toggled
class SnapToGridToggled extends WorkspaceEvent {
  const SnapToGridToggled();
}

/// Fired when rulers visibility is toggled
class RulersToggled extends WorkspaceEvent {
  const RulersToggled();
}

/// Fired when the user changes the default frame preset (used when creating
/// new frames with the Frame tool).
class FrameToolPresetChanged extends WorkspaceEvent {
  const FrameToolPresetChanged(this.presetId);

  /// Selected preset id, or null for custom/no default.
  final String? presetId;

  @override
  List<Object?> get props => [presetId];
}

/// Toggle the Layers panel search UI.
class LayersSearchToggled extends WorkspaceEvent {
  const LayersSearchToggled();
}

/// Set the Layers search query.
class LayersSearchQueryChanged extends WorkspaceEvent {
  const LayersSearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// Close Layers search and clear query.
class LayersSearchCleared extends WorkspaceEvent {
  const LayersSearchCleared();
}
