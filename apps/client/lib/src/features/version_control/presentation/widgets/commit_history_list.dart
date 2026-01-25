import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../../core/api/dto.dart';
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
            );
          },
        );
      },
    );
  }

  void _showCheckoutDialog(BuildContext context, CommitDto commit) {
    final nameController = TextEditingController(
      text: 'checkout-${commit.id.substring(0, 7)}',
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VioColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Checkout Commit',
          style: TextStyle(
            color: VioColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create a new branch from this commit:',
                style: TextStyle(
                  color: VioColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              _CommitPreview(commit: commit),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                style: const TextStyle(color: VioColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'New branch name',
                  labelStyle: const TextStyle(color: VioColors.textSecondary),
                  filled: true,
                  fillColor: VioColors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: VioColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: VioColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: VioColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: VioColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: VioColors.primary,
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
      ),
    );
  }

  void _showRevertDialog(BuildContext context, CommitDto commit) {
    final messageController = TextEditingController(
      text: 'Revert "${commit.message}"',
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VioColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Revert Commit',
          style: TextStyle(
            color: VioColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create a new commit that undoes the changes:',
                style: TextStyle(
                  color: VioColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              _CommitPreview(commit: commit),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                maxLines: 2,
                style: const TextStyle(color: VioColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Revert commit message',
                  labelStyle: const TextStyle(color: VioColors.textSecondary),
                  filled: true,
                  fillColor: VioColors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: VioColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: VioColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: VioColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: VioColors.textSecondary),
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
      ),
    );
  }

  void _showDiffDialog(
    BuildContext context,
    VersionControlState state,
    CommitDto commit,
  ) {
    // For now, show a placeholder. Full diff view would be a more complex widget.
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VioColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Commit Details',
          style: TextStyle(
            color: VioColors.textPrimary,
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
              const Text(
                'Diff visualization coming soon...',
                style: TextStyle(
                  color: VioColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: VioColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state when no commits exist
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: VioColors.textTertiary,
            ),
            SizedBox(height: 12),
            Text(
              'No commits yet',
              style: TextStyle(
                color: VioColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Make changes and create your first commit',
              style: TextStyle(
                color: VioColors.textTertiary,
                fontSize: 12,
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
  });

  final CommitDto commit;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onCheckout;
  final VoidCallback onRevert;
  final VoidCallback onViewDiff;

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
                    color: VioColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: VioColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Commit message
                      Text(
                        commit.message,
                        style: const TextStyle(
                          color: VioColors.textPrimary,
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
                          // Commit hash
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: VioColors.surface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              commit.id.length > 7
                                  ? commit.id.substring(0, 7)
                                  : commit.id,
                              style: const TextStyle(
                                color: VioColors.textSecondary,
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Timestamp
                          const Icon(
                            Icons.schedule,
                            size: 12,
                            color: VioColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(commit.createdAt),
                            style: const TextStyle(
                              color: VioColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                          const Spacer(),

                          // Action buttons
                          _CommitActions(
                            onCheckout: onCheckout,
                            onRevert: onRevert,
                          ),
                        ],
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
              color: isFirst ? Colors.transparent : VioColors.border,
            ),
          ),
          // Dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isFirst ? VioColors.primary : VioColors.surfaceElevated,
              shape: BoxShape.circle,
              border: Border.all(
                color: isFirst ? VioColors.primary : VioColors.border,
                width: 2,
              ),
            ),
          ),
          // Bottom line
          Expanded(
            child: Container(
              width: 2,
              color: isLast ? Colors.transparent : VioColors.border,
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
  });

  final VoidCallback onCheckout;
  final VoidCallback onRevert;

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
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.call_split,
                size: 14,
                color: VioColors.textSecondary,
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
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.undo,
                size: 14,
                color: VioColors.textSecondary,
              ),
            ),
          ),
        ),
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

  final CommitDto commit;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VioColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VioColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: VioColors.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  commit.id.length > 7 ? commit.id.substring(0, 7) : commit.id,
                  style: const TextStyle(
                    color: VioColors.primary,
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
            style: const TextStyle(
              color: VioColors.textPrimary,
              fontSize: 13,
            ),
            maxLines: expanded ? null : 2,
            overflow: expanded ? null : TextOverflow.ellipsis,
          ),
          if (expanded) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.schedule,
                  size: 12,
                  color: VioColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatFullDate(commit.createdAt),
                  style: const TextStyle(
                    color: VioColors.textTertiary,
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
