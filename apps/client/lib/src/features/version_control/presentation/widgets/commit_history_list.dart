import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../../core/core.dart';
import '../../../../gen/vio/v1/commit.pb.dart' as commit_pb;
import '../../bloc/version_control_bloc.dart';

/// Displays commit history as a timeline
class CommitHistoryList extends StatelessWidget {
  const CommitHistoryList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VersionControlBloc, VersionControlState>(
      builder: (context, state) {
        final commits = state.commits;

        if (commits.isEmpty) {
          return _EmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: commits.length,
          itemBuilder: (context, index) {
            final commit = commits[index];
            final isFirst = index == 0;
            final isLast = index == commits.length - 1;

            return _CommitItem(
              commit: commit,
              isFirst: isFirst,
              isLast: isLast,
              onCheckout: () => _showCheckoutDialog(context, commit),
              onRevert: () => _showRevertDialog(context, commit),
              onViewDiff: () => _showDiffDialog(context, state, commit),
              onCherryPick: state.currentBranchId != null
                  ? () => _showCherryPickDialog(context, state, commit)
                  : null,
            );
          },
        );
      },
    );
  }

  void _showCheckoutDialog(BuildContext context, commit_pb.Commit commit) {
    final nameController = TextEditingController(
      text: 'checkout-${commit.id.substring(0, 7)}',
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final dcs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: dcs.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Checkout Commit',
            style: TextStyle(
              color: dcs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create a new branch from this commit:',
                  style: TextStyle(
                    color: dcs.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                _CommitPreview(commit: commit),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  style: TextStyle(color: dcs.onSurface),
                  decoration: InputDecoration(
                    labelText: 'New branch name',
                    labelStyle: TextStyle(color: dcs.onSurfaceVariant),
                    filled: true,
                    fillColor: dcs.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: dcs.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: dcs.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: dcs.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: dcs.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: dcs.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                context.read<VersionControlBloc>().add(
                      CommitCheckoutRequested(
                        commitId: commit.id,
                        newBranchName: nameController.text.trim(),
                      ),
                    );
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Checkout'),
            ),
          ],
        );
      },
    );
  }

  void _showRevertDialog(BuildContext context, commit_pb.Commit commit) {
    final messageController = TextEditingController(
      text: 'Revert "${commit.message}"',
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final dcs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: dcs.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Revert Commit',
            style: TextStyle(
              color: dcs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create a new commit that undoes the changes:',
                  style: TextStyle(
                    color: dcs.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                _CommitPreview(commit: commit),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  maxLines: 2,
                  style: TextStyle(color: dcs.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Revert commit message',
                    labelStyle: TextStyle(color: dcs.onSurfaceVariant),
                    filled: true,
                    fillColor: dcs.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: dcs.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: dcs.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: dcs.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: dcs.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: VioColors.warning,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                context.read<VersionControlBloc>().add(
                      CommitRevertRequested(
                        commitId: commit.id,
                        message: messageController.text.trim(),
                      ),
                    );
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Revert'),
            ),
          ],
        );
      },
    );
  }

  void _showDiffDialog(
    BuildContext context,
    VersionControlState state,
    commit_pb.Commit commit,
  ) {
    // For now, show a placeholder. Full diff view would be a more complex widget.
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final dcs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: dcs.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Commit Details',
            style: TextStyle(
              color: dcs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CommitPreview(commit: commit, expanded: true),
                const SizedBox(height: 16),
                Text(
                  'Diff visualization coming soon...',
                  style: TextStyle(
                    color: dcs.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Close',
                style: TextStyle(color: dcs.onSurfaceVariant),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCherryPickDialog(
    BuildContext context,
    VersionControlState state,
    commit_pb.Commit commit,
  ) {
    final currentBranch = state.currentBranch;
    if (currentBranch == null) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final dcs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: dcs.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Cherry-pick Commit',
            style: TextStyle(
              color: dcs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Apply the changes from this commit to the current branch:',
                  style: TextStyle(color: dcs.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 12),
                _CommitPreview(commit: commit),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: dcs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.merge_type,
                        size: 14,
                        color: dcs.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Target: ${currentBranch.name}',
                          style: TextStyle(
                            color: dcs.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: dcs.onSurfaceVariant),
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.file_copy_outlined, size: 16),
              label: const Text('Cherry-pick'),
              style: ElevatedButton.styleFrom(
                backgroundColor: dcs.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                context.read<VersionControlBloc>().add(
                      CommitCherryPickRequested(
                        commitId: commit.id,
                        targetBranchId: currentBranch.id,
                      ),
                    );
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

/// Empty state when no commits exist
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: 32,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              'No commits yet',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Make changes and commit',
              style: TextStyle(
                color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Single commit item in the timeline
class _CommitItem extends StatelessWidget {
  const _CommitItem({
    required this.commit,
    required this.isFirst,
    required this.isLast,
    required this.onCheckout,
    required this.onRevert,
    required this.onViewDiff,
    this.onCherryPick,
  });

  final commit_pb.Commit commit;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onCheckout;
  final VoidCallback onRevert;
  final VoidCallback onViewDiff;
  final VoidCallback? onCherryPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onViewDiff,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Timeline indicator
              _TimelineIndicator(isFirst: isFirst, isLast: isLast),
              const SizedBox(width: 12),

              // Commit content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: .25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Commit message
                      Text(
                        commit.message,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // Commit metadata
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              commit.id.length > 7
                                  ? commit.id.substring(0, 7)
                                  : commit.id,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _formatDate(commit.createdAtDateTime),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _CommitActions(
                          onCheckout: onCheckout,
                          onRevert: onRevert,
                          onCherryPick: onCherryPick,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

/// Timeline indicator for commit list
class _TimelineIndicator extends StatelessWidget {
  const _TimelineIndicator({
    required this.isFirst,
    required this.isLast,
  });

  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      child: Column(
        children: [
          // Top line
          Expanded(
            child: Container(
              width: 2,
              color: isFirst
                  ? Colors.transparent
                  : Theme.of(context).colorScheme.outline,
            ),
          ),
          // Dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isFirst
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHigh,
              shape: BoxShape.circle,
              border: Border.all(
                color: isFirst
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
                width: 2,
              ),
            ),
          ),
          // Bottom line
          Expanded(
            child: SizedBox(
              width: 2,
              child: ColoredBox(
                color: isLast
                    ? Colors.transparent
                    : Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Action buttons for a commit
class _CommitActions extends StatelessWidget {
  const _CommitActions({
    required this.onCheckout,
    required this.onRevert,
    this.onCherryPick,
  });

  final VoidCallback onCheckout;
  final VoidCallback onRevert;
  final VoidCallback? onCherryPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'Checkout (create branch)',
          child: InkWell(
            onTap: onCheckout,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.call_split,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Tooltip(
          message: 'Revert commit',
          child: InkWell(
            onTap: onRevert,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.undo,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        if (onCherryPick != null) ...[
          const SizedBox(width: 4),
          Tooltip(
            message: 'Cherry-pick to current branch',
            child: InkWell(
              onTap: onCherryPick,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.file_copy_outlined,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Commit preview card for dialogs
class _CommitPreview extends StatelessWidget {
  const _CommitPreview({
    required this.commit,
    this.expanded = false,
  });

  final commit_pb.Commit commit;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  commit.id.length > 7 ? commit.id.substring(0, 7) : commit.id,
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            commit.message,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 13,
            ),
            maxLines: expanded ? null : 2,
            overflow: expanded ? null : TextOverflow.ellipsis,
          ),
          if (expanded) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 12,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatFullDate(commit.createdAtDateTime),
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
