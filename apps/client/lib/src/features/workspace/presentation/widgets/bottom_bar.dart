import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../canvas/bloc/canvas_bloc.dart';
import '../../bloc/workspace_bloc.dart';

/// Bottom bar with zoom controls and view settings
class BottomBar extends StatelessWidget {
  const BottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: const BoxDecoration(
        color: VioColors.surface1,
        border: Border(
          top: BorderSide(
            color: VioColors.border,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: VioSpacing.md),
          // Left side - status
          _buildStatusSection(context),
          const Spacer(),
          // Center - view toggles
          _buildViewToggles(context),
          const Spacer(),
          // Right side - zoom controls
          _buildZoomControls(context),
          const SizedBox(width: VioSpacing.md),
        ],
      ),
    );
  }

  Widget _buildStatusSection(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.circle,
          size: 8,
          color: VioColors.success,
        ),
        const SizedBox(width: VioSpacing.xs),
        Text(
          'Ready',
          style: VioTypography.caption.copyWith(
            color: VioColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildViewToggles(BuildContext context) {
    return BlocBuilder<WorkspaceBloc, WorkspaceState>(
      buildWhen: (prev, curr) =>
          prev.showGrid != curr.showGrid ||
          prev.snapToGrid != curr.snapToGrid ||
          prev.showRulers != curr.showRulers,
      builder: (context, state) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToggleButton(
              icon: Icons.grid_4x4,
              tooltip: 'Show Grid (Ctrl+`)',
              isActive: state.showGrid,
              onPressed: () {
                context.read<WorkspaceBloc>().add(const GridToggled());
              },
            ),
            _ToggleButton(
              icon: Icons.grid_on,
              tooltip: 'Snap to Grid (Ctrl+\')',
              isActive: state.snapToGrid,
              onPressed: () {
                context.read<WorkspaceBloc>().add(const SnapToGridToggled());
              },
            ),
            _ToggleButton(
              icon: Icons.straighten,
              tooltip: 'Show Rulers (Ctrl+Shift+R)',
              isActive: state.showRulers,
              onPressed: () {
                context.read<WorkspaceBloc>().add(const RulersToggled());
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildZoomControls(BuildContext context) {
    return BlocBuilder<CanvasBloc, CanvasState>(
      buildWhen: (prev, curr) => prev.zoom != curr.zoom,
      builder: (context, state) {
        final zoomPercentage = '${(state.zoom * 100).round()}%';
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Zoom out
            VioIconButton(
              icon: Icons.remove,
              size: 24,
              tooltip: 'Zoom Out (Ctrl+-)',
              onPressed: () {
                context.read<CanvasBloc>().add(const ZoomOut());
              },
            ),

            // Zoom percentage dropdown
            SizedBox(
              width: 64,
              child: PopupMenuButton<double>(
                initialValue: state.zoom,
                tooltip: 'Zoom Level',
                offset: const Offset(0, -200),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: VioSpacing.xs,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        zoomPercentage,
                        style: VioTypography.caption.copyWith(
                          color: VioColors.textSecondary,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        size: 16,
                        color: VioColors.textTertiary,
                      ),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 0.25, child: Text('25%')),
                  const PopupMenuItem(value: 0.5, child: Text('50%')),
                  const PopupMenuItem(value: 0.75, child: Text('75%')),
                  const PopupMenuItem(value: 1.0, child: Text('100%')),
                  const PopupMenuItem(value: 1.5, child: Text('150%')),
                  const PopupMenuItem(value: 2.0, child: Text('200%')),
                  const PopupMenuItem(value: 4.0, child: Text('400%')),
                  const PopupMenuItem(value: 8.0, child: Text('800%')),
                ],
                onSelected: (zoom) {
                  context.read<CanvasBloc>().add(ZoomSet(zoom));
                },
              ),
            ),

            // Zoom in
            VioIconButton(
              icon: Icons.add,
              size: 24,
              tooltip: 'Zoom In (Ctrl++)',
              onPressed: () {
                context.read<CanvasBloc>().add(const ZoomIn());
              },
            ),

            const SizedBox(width: VioSpacing.sm),

            // Fit to screen
            VioIconButton(
              icon: Icons.fit_screen,
              size: 24,
              tooltip: 'Fit to Screen',
              onPressed: () {
                context.read<CanvasBloc>().add(const ZoomSet(1.0));
              },
            ),
          ],
        );
      },
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: VioSpacing.xs,
            vertical: VioSpacing.xs / 2,
          ),
          child: Icon(
            icon,
            size: 16,
            color: isActive ? VioColors.primary : VioColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
