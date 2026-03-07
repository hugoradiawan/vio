import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_client/src/features/version_control/presentation/presentation.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../../gen/vio/v1/branch.pb.dart' as branch_pb;
import '../../bloc/version_control_bloc.dart';

/// Main version control tab content for the left panel
class VersionControlTab extends StatefulWidget {
  const VersionControlTab({super.key});

  @override
  State<VersionControlTab> createState() => _VersionControlTabState();
}

class _VersionControlTabState extends State<VersionControlTab> {
  final Map<String, bool> _expandedSections = <String, bool>{
    'commit': true,
    'branches': false,
    'history': true,
  };

  bool _isExpanded(String key) => _expandedSections[key] ?? true;

  void _setExpanded(String key, bool expanded) {
    setState(() {
      _expandedSections[key] = expanded;
    });
  }

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
            orElse: () => branch_pb.Branch()
              ..id = state.pendingSwitchBranchId!
              ..projectId = state.projectId ?? ''
              ..name = 'Unknown',
          );
          _showSwitchConfirmationDialog(context, branch);
        }

        // Show branch delete confirmation dialog
        if (state.pendingDeleteBranchId != null) {
          final branch = state.branches.firstWhere(
            (b) => b.id == state.pendingDeleteBranchId,
            orElse: () => branch_pb.Branch()
              ..id = state.pendingDeleteBranchId!
              ..projectId = state.projectId ?? ''
              ..name = 'Unknown',
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
            VioPanel(
              title: 'Commit',
              collapsible: true,
              padding: EdgeInsets.zero,
              isExpanded: _isExpanded('commit'),
              onExpansionChanged: (expanded) => _setExpanded(
                'commit',
                expanded,
              ),
              trailing: state.hasUncommittedChanges
                  ? Text(
                      '${state.uncommittedChanges.length} change${state.uncommittedChanges.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    )
                  : null,
              child: const CommitPanel(),
            ),

            // Branches section (collapsible)
            VioPanel(
              title: 'Branches',
              collapsible: true,
              padding: EdgeInsets.zero,
              initiallyExpanded: false,
              isExpanded: _isExpanded('branches'),
              onExpansionChanged: (expanded) => _setExpanded(
                'branches',
                expanded,
              ),
              trailing: Row(
                children: [
                  Text(
                    '${state.branches.length}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              child: _CollapsibleExpandedSection(
                title: 'History',
                isExpanded: _isExpanded('history'),
                onExpansionChanged: (expanded) => _setExpanded(
                  'history',
                  expanded,
                ),
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

  void _showSwitchConfirmationDialog(
    BuildContext context,
    branch_pb.Branch branch,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Theme.of(dialogContext).colorScheme.outline),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: VioColors.warning,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'Uncommitted Changes',
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          'You have uncommitted changes. What would you like to do before switching to "${branch.name}"?',
          style: TextStyle(color: Theme.of(dialogContext).colorScheme.onSurfaceVariant, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context
                  .read<VersionControlBloc>()
                  .add(const BranchSwitchCanceled());
            },
            child: Text(
              'Cancel',
              style: TextStyle(color: Theme.of(dialogContext).colorScheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context
                  .read<VersionControlBloc>()
                  .add(const BranchSwitchConfirmed());
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(dialogContext).colorScheme.error),
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
              backgroundColor: Theme.of(dialogContext).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Commit First'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(
    BuildContext context,
    branch_pb.Branch branch,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        title: Text(
          'Delete Branch?',
          style: TextStyle(color: Theme.of(dialogContext).colorScheme.onSurface),
        ),
        content: Text(
          'Are you sure you want to delete the branch "${branch.name}"? This action cannot be undone.',
          style: TextStyle(color: Theme.of(dialogContext).colorScheme.onSurfaceVariant),
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
            style: TextButton.styleFrom(foregroundColor: Theme.of(dialogContext).colorScheme.error),
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
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.source,
              size: 48,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Version Control',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Open a project to start tracking changes',
              style: TextStyle(
                color: cs.onSurfaceVariant,
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
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading version control...',
            style: TextStyle(
              color: cs.onSurfaceVariant,
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
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: cs.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Error loading version control',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              error,
              style: TextStyle(
                color: cs.onSurfaceVariant,
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
                foregroundColor: cs.primary,
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
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Refresh',
      child: InkWell(
        onTap: isLoading ? null : onRefresh,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: isLoading
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onSurfaceVariant,
                  ),
                )
              : Icon(
                  Icons.refresh,
                  size: 14,
                  color: cs.onSurfaceVariant,
                ),
        ),
      ),
    );
  }
}

class _CollapsibleExpandedSection extends StatelessWidget {
  const _CollapsibleExpandedSection({
    required this.title,
    required this.child,
    required this.isExpanded,
    required this.onExpansionChanged,
    this.trailing,
  });

  final String title;
  final Widget child;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outline)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => onExpansionChanged(!isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(VioSpacing.panelPadding),
              child: Row(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0.0,
                      end: isExpanded ? 0.5 : 0.0,
                    ),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    builder: (context, turns, child) {
                      return Transform.rotate(
                        angle: turns * 3.1415926535897932,
                        child: child,
                      );
                    },
                    child: Icon(
                      Icons.expand_more,
                      size: VioSpacing.iconSm,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: VioSpacing.xs),
                  Expanded(
                    child: Text(
                      title,
                      style: VioTypography.titleSmall.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          ),
          if (isExpanded)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(VioSpacing.panelPadding),
                child: child,
              ),
            ),
        ],
      ),
    );
  }
}
