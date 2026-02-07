import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_client/src/features/version_control/presentation/presentation.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../../core/api/dto.dart' show BranchDto;
import '../../bloc/version_control_bloc.dart';

/// Main version control tab content for the left panel
class VersionControlTab extends StatelessWidget {
  const VersionControlTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VersionControlBloc, VersionControlState>(
      listenWhen: (previous, current) =>
          previous.pendingSwitchBranchId != current.pendingSwitchBranchId ||
          previous.pendingDeleteBranchId != current.pendingDeleteBranchId,
      listener: (context, state) {
        // Show branch switch confirmation dialog
        if (state.pendingSwitchBranchId != null) {
          final branch = state.branches.firstWhere(
            (b) => b.id == state.pendingSwitchBranchId,
            orElse: () => BranchDto(
              id: state.pendingSwitchBranchId!,
              projectId: state.projectId ?? '',
              name: 'Unknown',
              isDefault: false,
              isProtected: false,
              createdById: '',
            ),
          );
          _showSwitchConfirmationDialog(context, branch);
        }

        // Show branch delete confirmation dialog
        if (state.pendingDeleteBranchId != null) {
          final branch = state.branches.firstWhere(
            (b) => b.id == state.pendingDeleteBranchId,
            orElse: () => BranchDto(
              id: state.pendingDeleteBranchId!,
              projectId: state.projectId ?? '',
              name: 'Unknown',
              isDefault: false,
              isProtected: false,
              createdById: '',
            ),
          );
          _showDeleteConfirmationDialog(context, branch);
        }
      },
      builder: (context, state) {
        if (state.status == VersionControlStatus.initial) {
          return _InitialState();
        }

        if (state.status == VersionControlStatus.loading &&
            state.branches.isEmpty) {
          return _LoadingState();
        }

        if (state.status == VersionControlStatus.error &&
            state.branches.isEmpty) {
          return _ErrorState(
            error: state.error ?? 'Unknown error',
            onRetry: () {
              if (state.projectId != null && state.userId != null) {
                context.read<VersionControlBloc>().add(
                      VersionControlInitialized(
                        projectId: state.projectId!,
                        userId: state.userId!,
                      ),
                    );
              }
            },
          );
        }

        return Column(
          children: [
            // Commit panel (collapsible)
            _CollapsibleSection(
              title: 'Commit',
              trailing: state.hasUncommittedChanges
                  ? Text(
                      '${state.uncommittedChanges.length} change${state.uncommittedChanges.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: VioColors.textTertiary,
                        fontSize: 11,
                      ),
                    )
                  : null,
              child: const CommitPanel(),
            ),

            // Branches section (collapsible)
            _CollapsibleSection(
              title: 'Branches',
              initiallyExpanded: false,
              trailing: Row(
                children: [
                  Text(
                    '${state.branches.length}',
                    style: const TextStyle(
                      color: VioColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _showCreateBranchDialog(context, state),
                    icon: const Icon(Icons.add),
                    iconSize: 18,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    color: VioColors.textSecondary,
                    tooltip: 'Create branch',
                  ),
                ],
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: const BranchListPanel(),
              ),
            ),

            // History section (collapsible, takes remaining space)
            Expanded(
              child: _CollapsibleSection(
                title: 'History',
                expandContent: true,
                trailing: _RefreshButton(
                  isLoading: state.status == VersionControlStatus.loading,
                  onRefresh: () {
                    context
                        .read<VersionControlBloc>()
                        .add(const CommitsRefreshRequested());
                  },
                ),
                child: const CommitHistoryList(),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCreateBranchDialog(
    BuildContext context,
    VersionControlState state,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => CreateBranchDialog(
        branches: state.branches,
        currentBranchId: state.currentBranchId,
        hasUncommittedChanges: state.hasUncommittedChanges,
        onCreateBranch: (name, description, sourceBranchId) {
          context.read<VersionControlBloc>().add(
                BranchCreateRequested(
                  name: name,
                  description: description,
                  sourceBranchId: sourceBranchId,
                ),
              );
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  void _showSwitchConfirmationDialog(BuildContext context, BranchDto branch) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VioColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: VioColors.border),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: VioColors.warning,
              size: 24,
            ),
            SizedBox(width: 12),
            Text(
              'Uncommitted Changes',
              style: TextStyle(
                color: VioColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          'You have uncommitted changes. What would you like to do before switching to "${branch.name}"?',
          style: const TextStyle(color: VioColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context
                  .read<VersionControlBloc>()
                  .add(const BranchSwitchCanceled());
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: VioColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context
                  .read<VersionControlBloc>()
                  .add(const BranchSwitchConfirmed());
            },
            style: TextButton.styleFrom(foregroundColor: VioColors.error),
            child: const Text('Discard Changes'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => BlocProvider.value(
                  value: context.read<VersionControlBloc>(),
                  child: CommitDialog(
                    targetBranchId: branch.id,
                    targetBranchName: branch.name,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: VioColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Commit First'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, BranchDto branch) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VioColors.surface,
        title: const Text(
          'Delete Branch?',
          style: TextStyle(color: VioColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete the branch "${branch.name}"? This action cannot be undone.',
          style: const TextStyle(color: VioColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context
                  .read<VersionControlBloc>()
                  .add(const BranchDeleteCanceled());
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context
                  .read<VersionControlBloc>()
                  .add(const BranchDeleteConfirmed());
            },
            style: TextButton.styleFrom(foregroundColor: VioColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Initial state before version control is initialized
class _InitialState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.source,
              size: 48,
              color: VioColors.textTertiary,
            ),
            SizedBox(height: 12),
            Text(
              'Version Control',
              style: TextStyle(
                color: VioColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Open a project to start tracking changes',
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

/// Loading state while fetching version control data
class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: VioColors.primary,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Loading version control...',
            style: TextStyle(
              color: VioColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Error state with retry option
class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.error,
    required this.onRetry,
  });

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: VioColors.error,
            ),
            const SizedBox(height: 12),
            const Text(
              'Error loading version control',
              style: TextStyle(
                color: VioColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              error,
              style: const TextStyle(
                color: VioColors.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: VioColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Refresh button with loading state
class _RefreshButton extends StatelessWidget {
  const _RefreshButton({
    required this.isLoading,
    required this.onRefresh,
  });

  final bool isLoading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Refresh',
      child: InkWell(
        onTap: isLoading ? null : onRefresh,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: isLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: VioColors.textTertiary,
                  ),
                )
              : const Icon(
                  Icons.refresh,
                  size: 14,
                  color: VioColors.textSecondary,
                ),
        ),
      ),
    );
  }
}

/// Collapsible section with header and content
class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({
    required this.title,
    required this.child,
    this.trailing,
    this.initiallyExpanded = true,
    this.expandContent = false,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final bool initiallyExpanded;

  /// If true, wraps the content in Expanded when visible (for use inside Column with Expanded parent)
  final bool expandContent;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: VioColors.surface,
              border: Border(
                bottom: BorderSide(color: VioColors.border),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 16,
                  color: VioColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.title.toUpperCase(),
                  style: const TextStyle(
                    color: VioColors.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
          ),
        ),
        // Content
        if (_isExpanded)
          widget.expandContent ? Expanded(child: widget.child) : widget.child,
      ],
    );
  }
}
