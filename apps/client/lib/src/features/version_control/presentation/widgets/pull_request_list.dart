import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../../core/api/dto.dart';
import '../../bloc/version_control_bloc.dart';
import 'conflict_resolution_dialog.dart';

/// Pull request list and detail view
class PullRequestList extends StatelessWidget {
  const PullRequestList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VersionControlBloc, VersionControlState>(
      builder: (context, state) {
        final pullRequests = state.pullRequests;

        if (pullRequests.isEmpty) {
          return _EmptyState(
            onCreatePr: () => _showCreatePrDialog(context, state),
          );
        }

        return Column(
          children: [
            // Header with create button
            _Header(
              count: state.openPullRequests.length,
              onCreate: () => _showCreatePrDialog(context, state),
            ),

            // Pull request list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: pullRequests.length,
                itemBuilder: (context, index) {
                  final pr = pullRequests[index];
                  final isSelected = state.selectedPullRequest?.id == pr.id;

                  return _PullRequestItem(
                    pullRequest: pr,
                    isSelected: isSelected,
                    onTap: () {
                      context.read<VersionControlBloc>().add(
                            PullRequestSelected(pullRequestId: pr.id),
                          );
                    },
                  );
                },
              ),
            ),

            // Selected PR detail panel
            if (state.selectedPullRequestDetail != null)
              _PullRequestDetailPanel(
                detail: state.selectedPullRequestDetail!,
                isMerging: state.status == VersionControlStatus.merging,
                onMerge: () => _showMergeConfirmation(context, state),
                onClose: () {
                  context.read<VersionControlBloc>().add(
                        PullRequestCloseRequested(
                          pullRequestId: state.selectedPullRequest!.id,
                        ),
                      );
                },
                onResolveConflicts: () {
                  _showConflictResolutionDialog(context, state);
                },
              ),
          ],
        );
      },
    );
  }

  void _showCreatePrDialog(BuildContext context, VersionControlState state) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => CreatePullRequestDialog(
        branches: state.branches,
        currentBranchId: state.currentBranchId,
        onCreatePr: (sourceBranchId, targetBranchId, title, description) {
          context.read<VersionControlBloc>().add(
                PullRequestCreateRequested(
                  sourceBranchId: sourceBranchId,
                  targetBranchId: targetBranchId,
                  title: title,
                  description: description,
                ),
              );
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  void _showMergeConfirmation(BuildContext context, VersionControlState state) {
    final pr = state.selectedPullRequest;
    if (pr == null) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => MergePullRequestDialog(
        pullRequest: pr,
        isMergeable: state.selectedPullRequestDetail?.mergeable ?? false,
        onMerge: (strategy, commitMessage) {
          context.read<VersionControlBloc>().add(
                PullRequestMergeRequested(
                  pullRequestId: pr.id,
                  strategy: strategy,
                  commitMessage: commitMessage,
                ),
              );
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  void _showConflictResolutionDialog(
    BuildContext context,
    VersionControlState state,
  ) {
    final detail = state.selectedPullRequestDetail;
    if (detail == null) return;

    final conflicts = detail.conflicts;
    if (conflicts.isEmpty) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ConflictResolutionDialog(
        conflicts: conflicts,
        sourceBranchName: detail.pullRequest.sourceBranchName ?? 'source',
        targetBranchName: detail.pullRequest.targetBranchName ?? 'target',
        onResolve: (resolutions) {
          context.read<VersionControlBloc>().add(
                ConflictsResolveRequested(
                  pullRequestId: detail.pullRequest.id,
                  resolutions: resolutions,
                ),
              );
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }
}

/// Empty state when no pull requests exist
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreatePr});

  final VoidCallback onCreatePr;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.call_merge,
              size: 48,
              color: VioColors.textTertiary,
            ),
            const SizedBox(height: 12),
            const Text(
              'No pull requests',
              style: TextStyle(
                color: VioColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Create a pull request to merge changes',
              style: TextStyle(
                color: VioColors.textTertiary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onCreatePr,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Pull Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: VioColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header with count and create button
class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.onCreate,
  });

  final int count;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: VioColors.surface,
        border: Border(
          bottom: BorderSide(color: VioColors.border),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'PULL REQUESTS',
            style: TextStyle(
              color: VioColors.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: VioColors.primary.withAlpha(51),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: VioColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          Tooltip(
            message: 'New Pull Request',
            child: InkWell(
              onTap: onCreate,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.add,
                  size: 16,
                  color: VioColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pull request item in the list
class _PullRequestItem extends StatelessWidget {
  const _PullRequestItem({
    required this.pullRequest,
    required this.isSelected,
    required this.onTap,
  });

  final PullRequestDto pullRequest;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? VioColors.primary.withAlpha(26)
              : VioColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? VioColors.primary : VioColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and status
            Row(
              children: [
                Expanded(
                  child: Text(
                    pullRequest.title,
                    style: const TextStyle(
                      color: VioColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusBadge(status: pullRequest.status),
              ],
            ),
            const SizedBox(height: 4),

            // Branch info
            Row(
              children: [
                const Icon(
                  Icons.call_merge,
                  size: 12,
                  color: VioColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${pullRequest.sourceBranchId.substring(0, 7)}... → ${pullRequest.targetBranchId.substring(0, 7)}...',
                    style: const TextStyle(
                      color: VioColors.textSecondary,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Status badge for pull requests
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final PullRequestStatus status;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case PullRequestStatus.open:
        bgColor = VioColors.success.withAlpha(51);
        textColor = VioColors.success;
        label = 'Open';
        break;
      case PullRequestStatus.merged:
        bgColor = VioColors.primary.withAlpha(51);
        textColor = VioColors.primary;
        label = 'Merged';
        break;
      case PullRequestStatus.closed:
        bgColor = VioColors.textTertiary.withAlpha(51);
        textColor = VioColors.textTertiary;
        label = 'Closed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Detail panel for selected pull request
class _PullRequestDetailPanel extends StatelessWidget {
  const _PullRequestDetailPanel({
    required this.detail,
    required this.isMerging,
    required this.onMerge,
    required this.onClose,
    required this.onResolveConflicts,
  });

  final PullRequestDetailDto detail;
  final bool isMerging;
  final VoidCallback onMerge;
  final VoidCallback onClose;
  final VoidCallback onResolveConflicts;

  @override
  Widget build(BuildContext context) {
    final canMerge = detail.mergeable;
    final hasConflicts = detail.hasConflicts;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: VioColors.surface,
        border: Border(
          top: BorderSide(color: VioColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Branch comparison
          Row(
            children: [
              _BranchChip(
                name: detail.pullRequest.sourceBranchName ?? 'Unknown',
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward,
                size: 16,
                color: VioColors.textTertiary,
              ),
              const SizedBox(width: 8),
              _BranchChip(
                name: detail.pullRequest.targetBranchName ?? 'Unknown',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Merge status
          if (hasConflicts) ...[
            _ConflictWarning(
              conflictCount: detail.conflicts.length,
              onResolve: onResolveConflicts,
            ),
            const SizedBox(height: 12),
          ] else if (canMerge) ...[
            _MergeReady(),
            const SizedBox(height: 12),
          ],

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onClose,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VioColors.textSecondary,
                    side: const BorderSide(color: VioColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: canMerge && !isMerging ? onMerge : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VioColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: VioColors.surfaceElevated,
                    disabledForegroundColor: VioColors.textTertiary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isMerging
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Merge'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Branch name chip
class _BranchChip extends StatelessWidget {
  const _BranchChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: VioColors.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: VioColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.merge,
            size: 12,
            color: VioColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            name,
            style: const TextStyle(
              color: VioColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Conflict warning banner
class _ConflictWarning extends StatelessWidget {
  const _ConflictWarning({
    required this.conflictCount,
    required this.onResolve,
  });

  final int conflictCount;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: VioColors.warning.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VioColors.warning.withAlpha(77)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber,
            size: 18,
            color: VioColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$conflictCount conflict${conflictCount > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: VioColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Text(
                  'Resolve before merging',
                  style: TextStyle(
                    color: VioColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onResolve,
            style: TextButton.styleFrom(
              foregroundColor: VioColors.warning,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
  }
}

/// Merge ready indicator
class _MergeReady extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: VioColors.success.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VioColors.success.withAlpha(77)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 18,
            color: VioColors.success,
          ),
          SizedBox(width: 8),
          Text(
            'Ready to merge',
            style: TextStyle(
              color: VioColors.success,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for creating a new pull request
class CreatePullRequestDialog extends StatefulWidget {
  const CreatePullRequestDialog({
    required this.branches,
    required this.currentBranchId,
    required this.onCreatePr,
    super.key,
  });

  final List<BranchDto> branches;
  final String? currentBranchId;
  final void Function(
    String sourceBranchId,
    String targetBranchId,
    String title,
    String? description,
  ) onCreatePr;

  @override
  State<CreatePullRequestDialog> createState() =>
      _CreatePullRequestDialogState();
}

class _CreatePullRequestDialogState extends State<CreatePullRequestDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _sourceBranchId;
  String? _targetBranchId;

  @override
  void initState() {
    super.initState();
    _sourceBranchId = widget.currentBranchId;
    // Default target to default branch
    _targetBranchId = widget.branches
        .firstWhere(
          (b) => b.isDefault,
          orElse: () => widget.branches.first,
        )
        .id;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VioColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        'Create Pull Request',
        style: TextStyle(
          color: VioColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Branch selectors
              Row(
                children: [
                  Expanded(
                    child: _BranchSelector(
                      label: 'From',
                      value: _sourceBranchId,
                      branches: widget.branches,
                      onChanged: (id) => setState(() => _sourceBranchId = id),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      Icons.arrow_forward,
                      color: VioColors.textTertiary,
                    ),
                  ),
                  Expanded(
                    child: _BranchSelector(
                      label: 'To',
                      value: _targetBranchId,
                      branches: widget.branches,
                      onChanged: (id) => setState(() => _targetBranchId = id),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: VioColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Title',
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
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                style: const TextStyle(color: VioColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
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
          onPressed: _sourceBranchId != null &&
                  _targetBranchId != null &&
                  _sourceBranchId != _targetBranchId
              ? () {
                  if (_formKey.currentState?.validate() ?? false) {
                    widget.onCreatePr(
                      _sourceBranchId!,
                      _targetBranchId!,
                      _titleController.text.trim(),
                      _descriptionController.text.trim().isEmpty
                          ? null
                          : _descriptionController.text.trim(),
                    );
                  }
                }
              : null,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

/// Branch selector dropdown
class _BranchSelector extends StatelessWidget {
  const _BranchSelector({
    required this.label,
    required this.value,
    required this.branches,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<BranchDto> branches;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: VioColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: VioColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: VioColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: VioColors.surface,
              icon: const Icon(
                Icons.expand_more,
                color: VioColors.textSecondary,
              ),
              style: const TextStyle(
                color: VioColors.textPrimary,
                fontSize: 13,
              ),
              onChanged: onChanged,
              items: branches.map((branch) {
                return DropdownMenuItem(
                  value: branch.id,
                  child: Text(
                    branch.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dialog for merge confirmation
class MergePullRequestDialog extends StatefulWidget {
  const MergePullRequestDialog({
    required this.pullRequest,
    required this.isMergeable,
    required this.onMerge,
    super.key,
  });

  final PullRequestDto pullRequest;
  final bool isMergeable;
  final void Function(MergeStrategy strategy, String? commitMessage) onMerge;

  @override
  State<MergePullRequestDialog> createState() => _MergePullRequestDialogState();
}

class _MergePullRequestDialogState extends State<MergePullRequestDialog> {
  final _messageController = TextEditingController();
  MergeStrategy _strategy = MergeStrategy.mergeCommit;

  @override
  void initState() {
    super.initState();
    _messageController.text = 'Merge: ${widget.pullRequest.title}';
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VioColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        'Merge Pull Request',
        style: TextStyle(
          color: VioColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.pullRequest.title,
              style: const TextStyle(
                color: VioColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),

            // Strategy selector
            const Text(
              'Merge Strategy',
              style: TextStyle(
                color: VioColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            _StrategySelector(
              value: _strategy,
              onChanged: (strategy) => setState(() => _strategy = strategy),
            ),
            const SizedBox(height: 16),

            // Commit message
            TextFormField(
              controller: _messageController,
              maxLines: 2,
              style: const TextStyle(color: VioColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Merge commit message',
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
          onPressed: () => Navigator.of(context).pop(),
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
          onPressed: widget.isMergeable
              ? () {
                  widget.onMerge(
                    _strategy,
                    _messageController.text.trim().isEmpty
                        ? null
                        : _messageController.text.trim(),
                  );
                }
              : null,
          child: const Text('Merge'),
        ),
      ],
    );
  }
}

/// Strategy selector for merge
class _StrategySelector extends StatelessWidget {
  const _StrategySelector({
    required this.value,
    required this.onChanged,
  });

  final MergeStrategy value;
  final void Function(MergeStrategy) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StrategyOption(
          strategy: MergeStrategy.mergeCommit,
          title: 'Merge Commit',
          description: 'Create a merge commit to combine branches',
          isSelected: value == MergeStrategy.mergeCommit,
          onTap: () => onChanged(MergeStrategy.mergeCommit),
        ),
        const SizedBox(height: 8),
        _StrategyOption(
          strategy: MergeStrategy.fastForward,
          title: 'Fast Forward',
          description: 'Move branch pointer without merge commit',
          isSelected: value == MergeStrategy.fastForward,
          onTap: () => onChanged(MergeStrategy.fastForward),
        ),
        const SizedBox(height: 8),
        _StrategyOption(
          strategy: MergeStrategy.squash,
          title: 'Squash',
          description: 'Combine all commits into a single commit',
          isSelected: value == MergeStrategy.squash,
          onTap: () => onChanged(MergeStrategy.squash),
        ),
      ],
    );
  }
}

/// Single strategy option
class _StrategyOption extends StatelessWidget {
  const _StrategyOption({
    required this.strategy,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  final MergeStrategy strategy;
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? VioColors.primary.withAlpha(26)
              : VioColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? VioColors.primary : VioColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: isSelected ? VioColors.primary : VioColors.textTertiary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: VioColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(
                      color: VioColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
