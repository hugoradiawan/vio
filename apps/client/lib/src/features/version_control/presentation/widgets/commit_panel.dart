import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../../core/core.dart';
import '../../../canvas/bloc/canvas_bloc.dart';
import '../../bloc/version_control_bloc.dart';
import '../../models/models.dart';

/// Commit panel for staging changes and creating commits
class CommitPanel extends StatefulWidget {
  const CommitPanel({super.key});

  @override
  State<CommitPanel> createState() => _CommitPanelState();
}

class _CommitPanelState extends State<CommitPanel> {
  final _messageController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSyncing = false;

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Sync canvas changes to server, then create commit
  Future<void> _syncAndCommit(BuildContext context) async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final vcBloc = context.read<VersionControlBloc>();

    // First, sync any pending canvas changes to the server
    setState(() => _isSyncing = true);

    try {
      // Sync directly via repository to ensure completion
      final repository = ServiceLocator.instance.canvasRepository;
      await repository.sync();

      // Now create the commit (server will read from shapes table)
      vcBloc.add(CommitCreateRequested(message: message));
      _messageController.clear();
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _showDiscardConfirmation(BuildContext context, String shapeId) {
    final vcBloc = context.read<VersionControlBloc>();
    final change = vcBloc.state.uncommittedChanges.firstWhere(
      (c) => c.shapeId == shapeId,
      orElse: () => throw StateError('Change not found'),
    );

    showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dcs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: dcs.surface,
          title: Text(
            'Discard Change',
            style: TextStyle(color: dcs.onSurface),
          ),
          content: Text(
            'Are you sure you want to discard changes to "${change.shapeName}"?',
            style: TextStyle(color: dcs.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: dcs.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    ).then((confirmed) {
      if (confirmed == true && context.mounted) {
        // Get the discarded shapes state
        final newShapes = vcBloc.getDiscardedShapesState(shapeId);
        if (newShapes != null) {
          // Update the canvas with the discarded state
          final canvasBloc = context.read<CanvasBloc>();

          // Apply changes to canvas
          final change = vcBloc.state.uncommittedChanges.firstWhere(
            (c) => c.shapeId == shapeId,
            orElse: () => throw StateError('Change not found'),
          );

          switch (change.changeType) {
            case ShapeChangeType.added:
              // Remove the shape from canvas
              canvasBloc.add(ShapeRemoved(shapeId: shapeId));
            case ShapeChangeType.modified:
              // Revert to base shape
              final baseShape = vcBloc.state.baseShapes[shapeId];
              if (baseShape != null) {
                canvasBloc.add(ShapeUpdated(baseShape));
              }
            case ShapeChangeType.deleted:
              // Restore the deleted shape
              final baseShape = vcBloc.state.baseShapes[shapeId];
              if (baseShape != null) {
                canvasBloc.add(ShapeAdded(baseShape));
              }
          }

          // Update VC bloc after canvas update
          vcBloc.add(ShapeChangeDiscarded(shapeId: shapeId));
        }
      }
    });
  }

  void _showDiscardAllConfirmation(BuildContext context, int changeCount) {
    final vcBloc = context.read<VersionControlBloc>();

    showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dcs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: dcs.surface,
          title: Text(
            'Discard All Changes',
            style: TextStyle(color: dcs.onSurface),
          ),
          content: Text(
            'Are you sure you want to discard all $changeCount change${changeCount == 1 ? '' : 's'}? This cannot be undone.',
            style: TextStyle(color: dcs.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: dcs.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Discard All'),
            ),
          ],
        );
      },
    ).then((confirmed) {
      if (confirmed == true && context.mounted) {
        final canvasBloc = context.read<CanvasBloc>();

        // Apply each change to canvas before discarding in VC bloc
        for (final change in vcBloc.state.uncommittedChanges) {
          switch (change.changeType) {
            case ShapeChangeType.added:
              canvasBloc.add(ShapeRemoved(shapeId: change.shapeId));
            case ShapeChangeType.modified:
              final baseShape = vcBloc.state.baseShapes[change.shapeId];
              if (baseShape != null) {
                canvasBloc.add(ShapeUpdated(baseShape));
              }
            case ShapeChangeType.deleted:
              final baseShape = vcBloc.state.baseShapes[change.shapeId];
              if (baseShape != null) {
                canvasBloc.add(ShapeAdded(baseShape));
              }
          }
        }

        // Update VC bloc
        vcBloc.add(const AllChangesDiscarded());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VersionControlBloc, VersionControlState>(
      builder: (context, state) {
        final isCommitting = state.status == VersionControlStatus.committing;
        final canCommit = state.canCommit && !isCommitting;
        final stagedChanges = state.stagedChanges;
        final uncommittedChanges = state.uncommittedChanges;
        final cs = Theme.of(context).colorScheme;

        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(
              bottom: BorderSide(color: cs.outline),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Changed files section
              if (uncommittedChanges.isNotEmpty) ...[
                _ChangedFilesList(
                  changes: uncommittedChanges,
                  stagedIds: state.stagedShapeIds,
                  onToggleStaged: (shapeId) {
                    final newStaged = Set<String>.from(state.stagedShapeIds);
                    if (newStaged.contains(shapeId)) {
                      newStaged.remove(shapeId);
                    } else {
                      newStaged.add(shapeId);
                    }
                    context.read<VersionControlBloc>().add(
                          ShapesStagedForCommit(shapeIds: newStaged.toList()),
                        );
                  },
                  onStageAll: () {
                    context.read<VersionControlBloc>().add(
                          ShapesStagedForCommit(
                            shapeIds: uncommittedChanges
                                .map((c) => c.shapeId)
                                .toList(),
                          ),
                        );
                  },
                  onUnstageAll: () {
                    context.read<VersionControlBloc>().add(
                          const StagedShapesCleared(),
                        );
                  },
                  onHoverChange: (shapeId) {
                    // Highlight the shape on canvas when hovering over a change
                    context.read<CanvasBloc>().add(LayerHovered(shapeId));
                  },
                  onDiscard: (shapeId) {
                    _showDiscardConfirmation(context, shapeId);
                  },
                  onDiscardAll: () {
                    _showDiscardAllConfirmation(
                      context,
                      uncommittedChanges.length,
                    );
                  },
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: cs.outline,
                      ),
                    ),
                    child: Builder(
                      builder: (context) {
                        final cs = Theme.of(context).colorScheme;
                        return Column(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 32,
                              color: cs.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No changes',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Commit message input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  maxLines: 3,
                  minLines: 2,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 12,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Commit message...',
                    hintStyle: TextStyle(color: cs.onSurfaceVariant),
                    filled: true,
                    fillColor: cs.surfaceContainerHigh,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: cs.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: cs.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: cs.primary),
                    ),
                  ),
                  enabled: !isCommitting,
                ),
              ),

              const SizedBox(height: 12),

              // Commit button
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        canCommit ? cs.primary : cs.surfaceContainerHigh,
                    foregroundColor:
                        canCommit ? Colors.white : cs.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: canCommit ? () => _syncAndCommit(context) : null,
                  child: isCommitting || _isSyncing
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onSurfaceVariant,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Commit${stagedChanges.isNotEmpty ? ' (${stagedChanges.length})' : ''}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// List of changed files/shapes
class _ChangedFilesList extends StatelessWidget {
  const _ChangedFilesList({
    required this.changes,
    required this.stagedIds,
    required this.onToggleStaged,
    required this.onStageAll,
    required this.onUnstageAll,
    required this.onDiscardAll,
    required this.onHoverChange,
    required this.onDiscard,
  });

  final List<ShapeChange> changes;
  final Set<String> stagedIds;
  final void Function(String shapeId) onToggleStaged;
  final VoidCallback onStageAll;
  final VoidCallback onUnstageAll;
  final VoidCallback onDiscardAll;
  final void Function(String? shapeId) onHoverChange;
  final void Function(String shapeId) onDiscard;

  @override
  Widget build(BuildContext context) {
    final stagedChanges =
        changes.where((c) => stagedIds.contains(c.shapeId)).toList();
    final unstagedChanges =
        changes.where((c) => !stagedIds.contains(c.shapeId)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Staged changes section
        if (stagedChanges.isNotEmpty) ...[
          _ChangesSection(
            title: 'Staged Changes',
            count: stagedChanges.length,
            actions: [
              _SectionIconButton(
                icon: Icons.remove_done,
                tooltip: 'Unstage All',
                onPressed: onUnstageAll,
              ),
            ],
            children: stagedChanges
                .map(
                  (change) => _ChangeItem(
                    change: change,
                    isStaged: true,
                    onToggle: () => onToggleStaged(change.shapeId),
                    onHover: (hovering) => onHoverChange(
                      hovering ? change.shapeId : null,
                    ),
                    onDiscard: () => onDiscard(change.shapeId),
                  ),
                )
                .toList(),
          ),
        ],

        // Unstaged changes section
        if (unstagedChanges.isNotEmpty) ...[
          _ChangesSection(
            title: 'Changes',
            count: unstagedChanges.length,
            actions: [
              _SectionIconButton(
                icon: Icons.done_all,
                tooltip: 'Stage All',
                onPressed: onStageAll,
              ),
              _SectionIconButton(
                icon: Icons.undo,
                tooltip: 'Discard All',
                onPressed: onDiscardAll,
              ),
            ],
            children: unstagedChanges
                .map(
                  (change) => _ChangeItem(
                    change: change,
                    isStaged: false,
                    onToggle: () => onToggleStaged(change.shapeId),
                    onHover: (hovering) => onHoverChange(
                      hovering ? change.shapeId : null,
                    ),
                    onDiscard: () => onDiscard(change.shapeId),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

/// Compact icon button for section actions
class _SectionIconButton extends StatelessWidget {
  const _SectionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 14,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(backgroundColor: Colors.transparent),
    );
  }
}

/// Section header for staged/unstaged changes
class _ChangesSection extends StatelessWidget {
  const _ChangesSection({
    required this.title,
    required this.count,
    required this.actions,
    required this.children,
  });

  final String title;
  final int count;
  final List<Widget> actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ),
              const Spacer(),
              ...actions,
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}

/// Individual change item with hover and discard support
class _ChangeItem extends StatefulWidget {
  const _ChangeItem({
    required this.change,
    required this.isStaged,
    required this.onToggle,
    required this.onHover,
    required this.onDiscard,
  });

  final ShapeChange change;
  final bool isStaged;
  final VoidCallback onToggle;
  final void Function(bool hovering) onHover;
  final VoidCallback onDiscard;

  @override
  State<_ChangeItem> createState() => _ChangeItemState();
}

class _ChangeItemState extends State<_ChangeItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<CanvasBloc, CanvasState, bool>(
      selector: (state) => state.hoveredShapeId == widget.change.shapeId,
      builder: (context, isCanvasHovered) {
        final highlighted = _isHovering || isCanvasHovered;
        return MouseRegion(
          onEnter: (_) {
            setState(() => _isHovering = true);
            widget.onHover(true);
          },
          onExit: (_) {
            setState(() => _isHovering = false);
            widget.onHover(false);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: highlighted
                  ? Theme.of(context).colorScheme.surfaceContainerHigh
                  : null,
              border: isCanvasHovered && !_isHovering
                  ? Border(
                      left: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    )
                  : null,
            ),
            child: Row(
              children: [
                // Checkbox - only this triggers stage/unstage
                GestureDetector(
                  onTap: widget.onToggle,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: widget.isStaged
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      border: Border.all(
                        color: widget.isStaged
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: widget.isStaged
                        ? const Icon(
                            Icons.check,
                            size: 12,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 8),

                // Change type indicator
                _ChangeTypeIcon(type: widget.change.changeType),
                const SizedBox(width: 8),

                // Shape name
                Expanded(
                  child: Text(
                    widget.change.shapeName,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                SizedBox(
                  height: 24,
                  child: Center(
                    child: _isHovering
                        ? IconButton(
                            onPressed: widget.onDiscard,
                            icon: Icon(
                              Icons.undo,
                              size: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            tooltip: 'Discard change',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 24,
                              minHeight: 24,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.transparent,
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.change.afterShape?.type.name ??
                                  widget.change.beforeShape?.type.name ??
                                  'shape',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 9,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Icon representing the type of change
class _ChangeTypeIcon extends StatelessWidget {
  const _ChangeTypeIcon({required this.type});

  final ShapeChangeType type;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;

    switch (type) {
      case ShapeChangeType.added:
        icon = Icons.add_circle;
        color = VioColors.success;
      case ShapeChangeType.modified:
        icon = Icons.edit;
        color = VioColors.warning;
      case ShapeChangeType.deleted:
        icon = Icons.remove_circle;
        color = Theme.of(context).colorScheme.error;
    }

    return Icon(icon, size: 14, color: color);
  }
}
