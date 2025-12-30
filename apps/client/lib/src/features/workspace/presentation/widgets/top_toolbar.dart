import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../bloc/workspace_bloc.dart';

/// Top toolbar containing tool selection and workspace actions
class TopToolbar extends StatelessWidget {
  const TopToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: VioColors.surface1,
        border: Border(
          bottom: BorderSide(
            color: VioColors.border,
          ),
        ),
      ),
      child: Row(
        children: [
          // Logo / Menu
          _buildMenuSection(),
          const SizedBox(width: VioSpacing.md),
          // Tools
          _buildToolsSection(context),
          const Spacer(),
          // Actions
          _buildActionsSection(context),
          const SizedBox(width: VioSpacing.md),
        ],
      ),
    );
  }

  Widget _buildMenuSection() {
    return Row(
      children: [
        const SizedBox(width: VioSpacing.md),
        // Logo
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: VioColors.primary,
            borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
          ),
          child: const Center(
            child: Text(
              'V',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: VioSpacing.md),
        // File menu
        _MenuButton(
          label: 'File',
          onPressed: () {},
        ),
        _MenuButton(
          label: 'Edit',
          onPressed: () {},
        ),
        _MenuButton(
          label: 'View',
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildToolsSection(BuildContext context) {
    return BlocBuilder<WorkspaceBloc, WorkspaceState>(
      buildWhen: (prev, curr) => prev.activeTool != curr.activeTool,
      builder: (context, state) {
        return VioCanvasToolbar(
          selectedToolId: _mapToolToToolItem(state.activeTool),
          onToolSelected: (tool) {
            final canvasTool = _mapToolItemToTool(tool);
            if (canvasTool != null) {
              context.read<WorkspaceBloc>().add(ToolSelected(canvasTool));
            }
          },
          tools: const [
            ToolbarToolItem(
              id: 'select',
              icon: Icons.near_me_outlined,
              tooltip: 'Select (V)',
            ),
            ToolbarToolItem(
              id: 'direct',
              icon: Icons.touch_app_outlined,
              tooltip: 'Direct Select (A)',
            ),
            ToolbarToolItem(
              id: 'rectangle',
              icon: Icons.rectangle_outlined,
              tooltip: 'Rectangle (R)',
            ),
            ToolbarToolItem(
              id: 'ellipse',
              icon: Icons.circle_outlined,
              tooltip: 'Ellipse (O)',
            ),
            ToolbarToolItem(
              id: 'path',
              icon: Icons.timeline,
              tooltip: 'Path (P)',
            ),
            ToolbarToolItem(
              id: 'text',
              icon: Icons.text_fields,
              tooltip: 'Text (T)',
            ),
            ToolbarToolItem(
              id: 'frame',
              icon: Icons.crop_free,
              tooltip: 'Frame (F)',
            ),
            ToolbarToolItem(
              id: 'hand',
              icon: Icons.pan_tool_outlined,
              tooltip: 'Hand (H)',
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionsSection(BuildContext context) {
    return Row(
      children: [
        // Share button
        VioButton(
          label: 'Share',
          variant: VioButtonVariant.ghost,
          size: VioButtonSize.small,
          leadingIcon: Icons.share_outlined,
          onPressed: () {},
        ),
        const SizedBox(width: VioSpacing.sm),
        // Export button
        VioButton(
          label: 'Export',
          size: VioButtonSize.small,
          leadingIcon: Icons.download_outlined,
          onPressed: () {},
        ),
      ],
    );
  }

  String? _mapToolToToolItem(CanvasTool tool) {
    return switch (tool) {
      CanvasTool.select => 'select',
      CanvasTool.directSelect => 'direct',
      CanvasTool.rectangle => 'rectangle',
      CanvasTool.ellipse => 'ellipse',
      CanvasTool.path => 'path',
      CanvasTool.text => 'text',
      CanvasTool.frame => 'frame',
      CanvasTool.hand => 'hand',
      CanvasTool.zoom => null,
      CanvasTool.comment => null,
    };
  }

  CanvasTool? _mapToolItemToTool(String id) {
    return switch (id) {
      'select' => CanvasTool.select,
      'direct' => CanvasTool.directSelect,
      'rectangle' => CanvasTool.rectangle,
      'ellipse' => CanvasTool.ellipse,
      'path' => CanvasTool.path,
      'text' => CanvasTool.text,
      'frame' => CanvasTool.frame,
      'hand' => CanvasTool.hand,
      _ => null,
    };
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: VioColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: VioSpacing.sm),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: VioTypography.body2.copyWith(
          color: VioColors.textSecondary,
        ),
      ),
    );
  }
}
