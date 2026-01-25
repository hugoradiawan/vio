import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../../core/api/dto.dart';
import '../../bloc/version_control_bloc.dart';

/// Sticky branch selector header that sits above the left panel
/// Option A: Branch selector in a compact sticky header above the entire left panel
class BranchSelectorHeader extends StatelessWidget {
  const BranchSelectorHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VersionControlBloc, VersionControlState>(
      builder: (context, state) {
        final currentBranch = state.currentBranch;
        final isLoading = state.status == VersionControlStatus.loading ||
            state.status == VersionControlStatus.switching;

        return Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: const BoxDecoration(
            color: VioColors.surface,
            border: Border(
              bottom: BorderSide(color: VioColors.border),
            ),
          ),
          child: Row(
            children: [
              // Git branch icon
              const Icon(
                Icons.merge,
                size: 16,
                color: VioColors.primary,
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
      BuildContext context, VersionControlState state,) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => CreateBranchDialog(
        currentBranchName: state.currentBranch?.name ?? 'main',
        onCreateBranch: (name, description) {
          context.read<VersionControlBloc>().add(
                BranchCreateRequested(
                  name: name,
                  description: description,
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
}

/// Branch dropdown selector
class _BranchDropdown extends StatelessWidget {
  const _BranchDropdown({
    required this.currentBranch,
    required this.branches,
    required this.isLoading,
    required this.onBranchSelected,
  });

  final BranchDto? currentBranch;
  final List<BranchDto> branches;
  final bool isLoading;
  final void Function(String branchId) onBranchSelected;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: VioColors.primary,
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Switching...',
            style: TextStyle(
              color: VioColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      offset: const Offset(0, 32),
      color: VioColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: VioColors.border),
      ),
      onSelected: onBranchSelected,
      itemBuilder: (context) => [
        // Default branches section
        if (branches.any((b) => b.isDefault)) ...[
          const PopupMenuItem<String>(
            enabled: false,
            height: 24,
            child: Text(
              'DEFAULT',
              style: TextStyle(
                color: VioColors.textTertiary,
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
          const PopupMenuItem<String>(
            enabled: false,
            height: 24,
            child: Text(
              'BRANCHES',
              style: TextStyle(
                color: VioColors.textTertiary,
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
          color: VioColors.surfaceElevated,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: VioColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                currentBranch?.name ?? 'No branch',
                style: const TextStyle(
                  color: VioColors.textPrimary,
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
                  color: VioColors.primary.withAlpha(51),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'default',
                  style: TextStyle(
                    color: VioColors.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(
              Icons.expand_more,
              size: 16,
              color: VioColors.textSecondary,
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

  final BranchDto branch;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (isSelected)
          const Icon(
            Icons.check,
            size: 14,
            color: VioColors.primary,
          )
        else
          const SizedBox(width: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            branch.name,
            style: TextStyle(
              color: isSelected ? VioColors.primary : VioColors.textPrimary,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (branch.isProtected) ...[
          const SizedBox(width: 4),
          const Icon(
            Icons.lock,
            size: 12,
            color: VioColors.textTertiary,
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
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.add,
                size: 18,
                color: VioColors.textSecondary,
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
                  const Icon(
                    Icons.call_merge,
                    size: 18,
                    color: VioColors.textSecondary,
                  ),
                  if (openPrCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: VioColors.primary,
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
    required this.currentBranchName, required this.onCreateBranch, super.key,
  });

  final String currentBranchName;
  final void Function(String name, String? description) onCreateBranch;

  @override
  State<CreateBranchDialog> createState() => _CreateBranchDialogState();
}

class _CreateBranchDialogState extends State<CreateBranchDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VioColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        'Create Branch',
        style: TextStyle(
          color: VioColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Creating branch from: ${widget.currentBranchName}',
                style: const TextStyle(
                  color: VioColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(color: VioColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Branch name',
                  labelStyle: const TextStyle(color: VioColors.textSecondary),
                  hintText: 'feature/my-feature',
                  hintStyle: const TextStyle(color: VioColors.textTertiary),
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
                style: const TextStyle(color: VioColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  labelStyle: const TextStyle(color: VioColors.textSecondary),
                  hintText: 'What is this branch for?',
                  hintStyle: const TextStyle(color: VioColors.textTertiary),
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
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              widget.onCreateBranch(
                _nameController.text.trim(),
                _descriptionController.text.trim().isEmpty
                    ? null
                    : _descriptionController.text.trim(),
              );
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
