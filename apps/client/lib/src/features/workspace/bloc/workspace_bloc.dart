import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'workspace_event.dart';
part 'workspace_state.dart';

/// Manages workspace-level state including:
/// - Active project
/// - Tool selection
/// - Panel visibility
/// - Zoom level
class WorkspaceBloc extends Bloc<WorkspaceEvent, WorkspaceState> {
  WorkspaceBloc() : super(const WorkspaceState()) {
    on<WorkspaceInitialized>(_onInitialized);
    on<ToolSelected>(_onToolSelected);
    on<LeftPanelToggled>(_onLeftPanelToggled);
    on<RightPanelToggled>(_onRightPanelToggled);
    on<ZoomChanged>(_onZoomChanged);
    on<GridToggled>(_onGridToggled);
    on<SnapToGridToggled>(_onSnapToGridToggled);
    on<RulersToggled>(_onRulersToggled);
    on<FrameToolPresetChanged>(_onFrameToolPresetChanged);
  }

  Future<void> _onInitialized(
    WorkspaceInitialized event,
    Emitter<WorkspaceState> emit,
  ) async {
    emit(state.copyWith(status: WorkspaceStatus.ready));
  }

  void _onToolSelected(
    ToolSelected event,
    Emitter<WorkspaceState> emit,
  ) {
    emit(state.copyWith(activeTool: event.tool));
  }

  void _onLeftPanelToggled(
    LeftPanelToggled event,
    Emitter<WorkspaceState> emit,
  ) {
    emit(state.copyWith(isLeftPanelVisible: !state.isLeftPanelVisible));
  }

  void _onRightPanelToggled(
    RightPanelToggled event,
    Emitter<WorkspaceState> emit,
  ) {
    emit(state.copyWith(isRightPanelVisible: !state.isRightPanelVisible));
  }

  void _onZoomChanged(
    ZoomChanged event,
    Emitter<WorkspaceState> emit,
  ) {
    // Clamp zoom between 1% and 6400%
    final clampedZoom = event.zoom.clamp(0.01, 64.0);
    emit(state.copyWith(zoom: clampedZoom));
  }

  void _onGridToggled(
    GridToggled event,
    Emitter<WorkspaceState> emit,
  ) {
    emit(state.copyWith(showGrid: !state.showGrid));
  }

  void _onSnapToGridToggled(
    SnapToGridToggled event,
    Emitter<WorkspaceState> emit,
  ) {
    emit(state.copyWith(snapToGrid: !state.snapToGrid));
  }

  void _onRulersToggled(
    RulersToggled event,
    Emitter<WorkspaceState> emit,
  ) {
    emit(state.copyWith(showRulers: !state.showRulers));
  }

  void _onFrameToolPresetChanged(
    FrameToolPresetChanged event,
    Emitter<WorkspaceState> emit,
  ) {
    emit(state.copyWith(frameToolPresetId: event.presetId));
  }
}
