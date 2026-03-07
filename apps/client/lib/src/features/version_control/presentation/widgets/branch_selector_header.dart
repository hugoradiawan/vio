import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../../gen/vio/v1/branch.pb.dart' as branch_pb;
import '../../bloc/version_control_bloc.dart';
import 'commit_dialog.dart';

/// Sticky branch selector header that sits above the left panel
/// Option A: Branch selector in a compact sticky header above the entire left panel
class BranchSelectorHeader extends StatelessWidget {
  const BranchSelectorHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VersionControlBloc, VersionControlState>(
      listenWhen: (previous, current) =>
          previous.pendingSwitchBranchId != current.pendingSwitchBranchId ||
          previous.pendingDeleteBranchId != current.pendingDeleteBranchId,
      listener: (context, state) {
        // Handle branch switch confirmation
        if (state.pendingSwitchBranchId != null) {
          final pendingBranch = state.branches.firstWhere(
            (b) => b.id == state.pendingSwitchBranchId,
            orElse: () => branch_pb.Branch()
              ..id = state.pendingSwitchBranchId!
              ..name = 'branch'
              ..projectId = state.projectId ?? '',
          );
          _showUncommittedChangesDialog(
            context,
            pendingBranch.name,
            pendingBranch.id,
          );
        }

        // Handle branch delete confirmation
        if (state.pendingDeleteBranchId != null) {
          final pendingBranch = state.branches.firstWhere(
            (b) => b.id == state.pendingDeleteBranchId,
            orElse: () => branch_pb.Branch()
              ..id = state.pendingDeleteBranchId!
              ..name = 'branch'
              ..projectId = state.projectId ?? '',
          );
          _showDeleteBranchDialog(context, pendingBranch);
        }
      },
      builder: (context, state) {
        final cs = Theme.of(context).colorScheme;
        final currentBranch = state.currentBranch;
        final isLoading = state.status == VersionControlStatus.loading ||
            state.status == VersionControlStatus.switching;

        return Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(
              bottom: BorderSide(color: cs.outline),
            ),
          ),
          child: Row(
            children: [
              // Git branch icon
              Icon(
                Icons.merge,
                size: 16,
                color: cs.primary,
              ),
              const SizedBox(width: 6),

              // Branch dropdown
              Expanded(
                child: _BranchDropdown(
                  currentBranch: currentBranch,
                  branches: state.branches,
                  isLoading: isLoading,
                  onBranchSelected: (branchId) {
                    context
                        .read<VersionControlBloc>()
                        .add(BranchSwitchRequested(branchId: branchId));
                  },
                ),
              ),

              // Action buttons
              _BranchActionButtons(
                hasUncommittedChanges: state.hasUncommittedChanges,
                openPrCount: state.openPullRequests.length,
                onCreateBranch: () => _showCreateBranchDialog(context, state),
                onShowPullRequests: () => _showPullRequestsPanel(context),
              ),
            ],
          ),
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

  void _showPullRequestsPanel(BuildContext context) {
    // This will be handled by workspace bloc to show PR panel
    // For now, just refresh the PR list
    context
        .read<VersionControlBloc>()
        .add(const PullRequestsRefreshRequested());
  }

  /// Show confirmation dialog when switching branches with uncommitted changes
  void _showUncommittedChangesDialog(
    BuildContext context,
    String branchName,
    String branchId,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final dcs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: dcs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: dcs.outline),
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
                  color: dcs.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Text(
            'You have uncommitted changes. What would you like to do before switching to "$branchName"?',
            style: TextStyle(
              color: dcs.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          actions: [
            // Cancel button
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context
                    .read<VersionControlBloc>()
                    .add(const BranchSwitchCanceled());
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: dcs.onSurfaceVariant),
              ),
            ),
            // Discard changes button
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context
                    .read<VersionControlBloc>()
                    .add(const BranchSwitchConfirmed());
              },
              style: TextButton.styleFrom(
                foregroundColor: dcs.error,
              ),
              child: const Text('Discard Changes'),
            ),
            // Commit first button (primary action)
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => BlocProvider.value(
                    value: context.read<VersionControlBloc>(),
                    child: CommitDialog(
                      targetBranchId: branchId,
                      targetBranchName: branchName,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: dcs.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Commit First'),
            ),
          ],
        );
      },
    );
  }

  /// Show confirmation dialog before deleting a branch
  void _showDeleteBranchDialog(BuildContext context, branch_pb.Branch branch) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final dcs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: dcs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: dcs.outline),
          ),
          title: Row(
            children: [
              Icon(
                Icons.delete_outline,
                color: dcs.error,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Delete Branch',
                style: TextStyle(
                  color: dcs.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete the branch "${branch.name}"?',
                style: TextStyle(
                  color: dcs.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This action cannot be undone. All commits unique to this branch will be lost.',
                style: TextStyle(
                  color: dcs.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            // Cancel button
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context
                    .read<VersionControlBloc>()
                    .add(const BranchDeleteCanceled());
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: dcs.onSurfaceVariant),
              ),
            ),
            // Delete button
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context
                    .read<VersionControlBloc>()
                    .add(const BranchDeleteConfirmed());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: dcs.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete Branch'),
            ),
          ],
        );
      },
    );
  }
}

/// Branch dropdown selector
class _BranchDropdown extends StatelessWidget {
  const _BranchDropdown({
    required this.currentBranch,
    required this.branches,
    required this.isLoading,
    required this.onBranchSelected,
  });

  final branch_pb.Branch? currentBranch;
  final List<branch_pb.Branch> branches;
  final bool isLoading;
  final void Function(String branchId) onBranchSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (isLoading) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Switching...',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      offset: const Offset(0, 32),
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: cs.outline),
      ),
      onSelected: onBranchSelected,
      itemBuilder: (context) => [
        // Default branches section
        if (branches.any((b) => b.isDefault)) ...[
          PopupMenuItem<String>(
            enabled: false,
            height: 24,
            child: Text(
              'DEFAULT',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ),
          ...branches.where((b) => b.isDefault).map(
                (branch) => PopupMenuItem<String>(
                  value: branch.id,
                  child: _BranchMenuItem(
                    branch: branch,
                    isSelected: branch.id == currentBranch?.id,
                  ),
                ),
              ),
          const PopupMenuDivider(),
        ],
        // Other branches
        if (branches.any((b) => !b.isDefault)) ...[
          PopupMenuItem<String>(
            enabled: false,
            height: 24,
            child: Text(
              'BRANCHES',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ),
          ...branches.where((b) => !b.isDefault).map(
                (branch) => PopupMenuItem<String>(
                  value: branch.id,
                  child: _BranchMenuItem(
                    branch: branch,
                    isSelected: branch.id == currentBranch?.id,
                  ),
                ),
              ),
        ],
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                currentBranch?.name ?? 'No branch',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (currentBranch?.isDefault == true) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'default',
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more,
              size: 16,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Branch menu item
class _BranchMenuItem extends StatelessWidget {
  const _BranchMenuItem({
    required this.branch,
    required this.isSelected,
  });

  final branch_pb.Branch branch;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (isSelected)
          Icon(
            Icons.check,
            size: 14,
            color: cs.primary,
          )
        else
          const SizedBox(width: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            branch.name,
            style: TextStyle(
              color: isSelected ? cs.primary : cs.onSurface,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (branch.isProtected) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.lock,
            size: 12,
            color: cs.onSurfaceVariant,
          ),
        ],
      ],
    );
  }
}

/// Action buttons for branch header
class _BranchActionButtons extends StatelessWidget {
  const _BranchActionButtons({
    required this.hasUncommittedChanges,
    required this.openPrCount,
    required this.onCreateBranch,
    required this.onShowPullRequests,
  });

  final bool hasUncommittedChanges;
  final int openPrCount;
  final VoidCallback onCreateBranch;
  final VoidCallback onShowPullRequests;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Uncommitted changes indicator
        if (hasUncommittedChanges)
          Tooltip(
            message: 'Uncommitted changes',
            child: Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                color: VioColors.warning,
                shape: BoxShape.circle,
              ),
            ),
          ),

        // Create branch button
        Tooltip(
          message: 'Create branch',
          child: InkWell(
            onTap: onCreateBranch,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.add,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ),

        // Pull requests button with badge
        Tooltip(
          message: openPrCount > 0
              ? '$openPrCount open pull request${openPrCount > 1 ? 's' : ''}'
              : 'Pull requests',
          child: InkWell(
            onTap: onShowPullRequests,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.call_merge,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                  if (openPrCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          openPrCount > 9 ? '9+' : openPrCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dialog for creating a new branch
class CreateBranchDialog extends StatefulWidget {
  const CreateBranchDialog({
    required this.branches,
    required this.currentBranchId,
    required this.hasUncommittedChanges,
    required this.onCreateBranch,
    super.key,
  });

  final List<branch_pb.Branch> branches;
  final String? currentBranchId;
  final bool hasUncommittedChanges;
  final void Function(String name, String? description, String sourceBranchId)
      onCreateBranch;

  @override
  State<CreateBranchDialog> createState() => _CreateBranchDialogState();
}

class _CreateBranchDialogState extends State<CreateBranchDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late String _selectedSourceBranchId;

  @override
  void initState() {
    super.initState();
    _selectedSourceBranchId = widget.currentBranchId ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        'Create Branch',
        style: TextStyle(
          color: cs.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Source branch selector
              Text(
                'Source branch',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.outline),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSourceBranchId,
                    isExpanded: true,
                    dropdownColor: cs.surfaceContainerHigh,
                    style: TextStyle(color: cs.onSurface),
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: cs.onSurfaceVariant,
                    ),
                    items: widget.branches.map((branch) {
                      return DropdownMenuItem<String>(
                        value: branch.id,
                        child: Row(
                          children: [
                            Icon(
                              branch.isDefault
                                  ? Icons.star
                                  : Icons.call_split_rounded,
                              size: 14,
                              color: branch.isDefault
                                  ? VioColors.warning
                                  : cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                branch.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (branch.id == widget.currentBranchId)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'current',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: cs.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedSourceBranchId = value);
                      }
                    },
                  ),
                ),
              ),

              // Warning about uncommitted changes
              if (widget.hasUncommittedChanges &&
                  _selectedSourceBranchId == widget.currentBranchId) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: VioColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: VioColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: VioColors.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Uncommitted changes will be carried over to the new branch.',
                          style: TextStyle(
                            fontSize: 11,
                            color: VioColors.warning.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: 'Branch name',
                  labelStyle: TextStyle(color: cs.onSurfaceVariant),
                  hintText: 'feature/my-feature',
                  hintStyle: TextStyle(color: cs.onSurfaceVariant),
                  filled: true,
                  fillColor: cs.surfaceContainerHigh,
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
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Branch name is required';
                  }
                  // Basic branch name validation
                  final regex = RegExp(r'^[a-zA-Z0-9_\-\/]+$');
                  if (!regex.hasMatch(value)) {
                    return 'Invalid branch name format';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  labelStyle: TextStyle(color: cs.onSurfaceVariant),
                  hintText: 'What is this branch for?',
                  hintStyle: TextStyle(color: cs.onSurfaceVariant),
                  filled: true,
                  fillColor: cs.surfaceContainerHigh,
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
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              widget.onCreateBranch(
                _nameController.text.trim(),
                _descriptionController.text.trim().isEmpty
                    ? null
                    : _descriptionController.text.trim(),
                _selectedSourceBranchId,
              );
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

