import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../../core/api/dto.dart';
import '../../bloc/version_control_bloc.dart';
import 'branch_selector_header.dart';
import 'branch_settings_dialog.dart';

/// Panel showing all branches with management options
///
/// Features:
/// - List of all branches (sorted: default first, then alphabetically)
/// - Current branch indicator
/// - Branch status badges (default, protected)
/// - Quick actions (switch, delete, create PR)
/// - Search/filter branches
/// - Create new branch button
class BranchListPanel extends StatefulWidget {
  const BranchListPanel({super.key});

  @override
  State<BranchListPanel> createState() => _BranchListPanelState();
}

class _BranchListPanelState extends State<BranchListPanel> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VersionControlBloc, VersionControlState>(
      builder: (context, state) {
        final branches = _filterBranches(state.branches, _searchQuery);
        final isLoading = state.status == VersionControlStatus.loading;

        return Container(
          decoration: const BoxDecoration(
            color: VioColors.surface,
            border: Border(
              right: BorderSide(color: VioColors.border),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildHeader(context, state),

              // Search bar
              _buildSearchBar(),

              // Branch list
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: VioColors.primary,
                        ),
                      )
                    : branches.isEmpty
                        ? _buildEmptyState()
                        : _buildBranchList(context, state, branches),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, VersionControlState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: VioColors.border),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.account_tree,
            size: 18,
            color: VioColors.primary,
          ),
          const SizedBox(width: 8),
          const Text(
            'Branches',
            style: TextStyle(
              color: VioColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // Branch count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: VioColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${state.branches.length}',
              style: const TextStyle(
                color: VioColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Create branch button
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
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(
          color: VioColors.textPrimary,
          fontSize: 13,
        ),
        decoration: InputDecoration(
          hintText: 'Search branches...',
          hintStyle: const TextStyle(
            color: VioColors.textTertiary,
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search,
            size: 18,
            color: VioColors.textTertiary,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  color: VioColors.textTertiary,
                )
              : null,
          filled: true,
          fillColor: VioColors.surfaceElevated,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: VioColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: VioColors.primary),
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off,
              size: 48,
              color: VioColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'No branches matching "$_searchQuery"',
              style: const TextStyle(
                color: VioColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 48,
            color: VioColors.textTertiary,
          ),
          SizedBox(height: 12),
          Text(
            'No branches found',
            style: TextStyle(
              color: VioColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchList(
    BuildContext context,
    VersionControlState state,
    List<BranchDto> branches,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: branches.length,
      itemBuilder: (context, index) {
        final branch = branches[index];
        final isCurrentBranch = branch.id == state.currentBranchId;

        return BranchListItem(
          branch: branch,
          isCurrentBranch: isCurrentBranch,
          onTap: () {
            if (!isCurrentBranch) {
              context.read<VersionControlBloc>().add(
                    BranchSwitchRequested(branchId: branch.id),
                  );
            }
          },
          onDelete: () {
            context.read<VersionControlBloc>().add(
                  BranchDeleteRequested(branchId: branch.id),
                );
          },
          onCreatePR: () {
            // Create PR from this branch to default
            final defaultBranch = state.defaultBranch;
            if (defaultBranch != null && defaultBranch.id != branch.id) {
              _showCreatePRDialog(context, branch, defaultBranch);
            }
          },
        );
      },
    );
  }

  List<BranchDto> _filterBranches(List<BranchDto> branches, String query) {
    var filtered = branches;

    // Filter by search query
    if (query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      filtered = filtered
          .where((b) => b.name.toLowerCase().contains(lowerQuery))
          .toList();
    }

    // Sort: default branch first, then alphabetically
    filtered.sort((a, b) {
      if (a.isDefault && !b.isDefault) return -1;
      if (!a.isDefault && b.isDefault) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return filtered;
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

  void _showCreatePRDialog(
    BuildContext context,
    BranchDto sourceBranch,
    BranchDto targetBranch,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _CreatePRFromBranchDialog(
        sourceBranch: sourceBranch,
        targetBranch: targetBranch,
        onCreatePR: (title, description) {
          context.read<VersionControlBloc>().add(
                PullRequestCreateRequested(
                  sourceBranchId: sourceBranch.id,
                  targetBranchId: targetBranch.id,
                  title: title,
                  description: description,
                ),
              );
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }
}

/// Individual branch list item with actions
class BranchListItem extends StatefulWidget {
  const BranchListItem({
    required this.branch,
    required this.isCurrentBranch,
    required this.onTap,
    required this.onDelete,
    required this.onCreatePR,
    super.key,
  });

  final BranchDto branch;
  final bool isCurrentBranch;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onCreatePR;

  @override
  State<BranchListItem> createState() => _BranchListItemState();
}

class _BranchListItemState extends State<BranchListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapDown: (details) {
          _showContextMenu(context, details.globalPosition);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isCurrentBranch
                ? VioColors.primary.withAlpha(26)
                : _isHovered
                    ? VioColors.surfaceElevated
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: widget.isCurrentBranch
                ? Border.all(color: VioColors.primary.withAlpha(77))
                : null,
          ),
          child: Row(
            children: [
              // Branch icon
              Icon(
                widget.isCurrentBranch ? Icons.check_circle : Icons.merge,
                size: 16,
                color: widget.isCurrentBranch
                    ? VioColors.primary
                    : VioColors.textTertiary,
              ),
              const SizedBox(width: 8),

              // Branch name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.branch.name,
                      style: TextStyle(
                        color: widget.isCurrentBranch
                            ? VioColors.primary
                            : VioColors.textPrimary,
                        fontSize: 13,
                        fontWeight: widget.isCurrentBranch
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.branch.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.branch.description!,
                        style: const TextStyle(
                          color: VioColors.textTertiary,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Badges
              if (widget.branch.isDefault) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                const SizedBox(width: 4),
              ],
              if (widget.branch.isProtected) ...[
                const Icon(
                  Icons.lock,
                  size: 12,
                  color: VioColors.textTertiary,
                ),
                const SizedBox(width: 4),
              ],

              // Action buttons (visible on hover)
              if (_isHovered && !widget.isCurrentBranch) ...[
                _HoverActionButton(
                  icon: Icons.call_merge,
                  tooltip: 'Create Pull Request',
                  onTap: widget.onCreatePR,
                ),
                if (!widget.branch.isDefault && !widget.branch.isProtected)
                  _HoverActionButton(
                    icon: Icons.delete_outline,
                    tooltip: 'Delete branch',
                    onTap: widget.onDelete,
                    color: VioColors.error,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      color: VioColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: VioColors.border),
      ),
      items: [
        if (!widget.isCurrentBranch)
          const PopupMenuItem<String>(
            value: 'switch',
            child: Row(
              children: [
                Icon(
                  Icons.swap_horiz,
                  size: 16,
                  color: VioColors.textSecondary,
                ),
                SizedBox(width: 8),
                Text('Switch to branch', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        if (!widget.branch.isDefault)
          const PopupMenuItem<String>(
            value: 'create_pr',
            child: Row(
              children: [
                Icon(
                  Icons.call_merge,
                  size: 16,
                  color: VioColors.textSecondary,
                ),
                SizedBox(width: 8),
                Text('Create Pull Request', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        const PopupMenuItem<String>(
          value: 'compare',
          child: Row(
            children: [
              Icon(
                Icons.compare_arrows,
                size: 16,
                color: VioColors.textSecondary,
              ),
              SizedBox(width: 8),
              Text('Compare with default', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings, size: 16, color: VioColors.textSecondary),
              SizedBox(width: 8),
              Text('Branch settings', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        if (!widget.branch.isDefault && !widget.branch.isProtected)
          const PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 16, color: VioColors.error),
                SizedBox(width: 8),
                Text(
                  'Delete branch',
                  style: TextStyle(fontSize: 13, color: VioColors.error),
                ),
              ],
            ),
          ),
      ],
    ).then((value) {
      if (value == null || !context.mounted) return;

      switch (value) {
        case 'switch':
          widget.onTap();
          break;
        case 'create_pr':
          widget.onCreatePR();
          break;
        case 'compare':
          final state = context.read<VersionControlBloc>().state;
          final defaultBranch = state.defaultBranch;
          if (defaultBranch != null) {
            context.read<VersionControlBloc>().add(
                  BranchCompareRequested(
                    baseBranchId: defaultBranch.id,
                    headBranchId: widget.branch.id,
                  ),
                );
          }
          break;
        case 'settings':
          showBranchSettingsDialog(context, widget.branch);
          break;
        case 'delete':
          widget.onDelete();
          break;
      }
    });
  }
}

/// Small hover action button
class _HoverActionButton extends StatelessWidget {
  const _HoverActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 14,
            color: color ?? VioColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Dialog to create a PR from the branch list
class _CreatePRFromBranchDialog extends StatefulWidget {
  const _CreatePRFromBranchDialog({
    required this.sourceBranch,
    required this.targetBranch,
    required this.onCreatePR,
  });

  final BranchDto sourceBranch;
  final BranchDto targetBranch;
  final void Function(String title, String? description) onCreatePR;

  @override
  State<_CreatePRFromBranchDialog> createState() =>
      _CreatePRFromBranchDialogState();
}

class _CreatePRFromBranchDialogState extends State<_CreatePRFromBranchDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Default title
    _titleController.text =
        'Merge ${widget.sourceBranch.name} into ${widget.targetBranch.name}';
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: VioColors.border),
      ),
      title: const Row(
        children: [
          Icon(Icons.call_merge, color: VioColors.primary, size: 24),
          SizedBox(width: 12),
          Text(
            'Create Pull Request',
            style: TextStyle(
              color: VioColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Branch indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VioColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'From',
                          style: TextStyle(
                            color: VioColors.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          widget.sourceBranch.name,
                          style: const TextStyle(
                            color: VioColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward,
                    color: VioColors.textTertiary,
                    size: 16,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Into',
                          style: TextStyle(
                            color: VioColors.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          widget.targetBranch.name,
                          style: const TextStyle(
                            color: VioColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Title field
            const Text(
              'Title',
              style: TextStyle(
                color: VioColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _titleController,
              style: const TextStyle(
                color: VioColors.textPrimary,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'Pull request title',
                hintStyle: const TextStyle(color: VioColors.textTertiary),
                filled: true,
                fillColor: VioColors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: VioColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: VioColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: VioColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Description field
            const Text(
              'Description (optional)',
              style: TextStyle(
                color: VioColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              style: const TextStyle(
                color: VioColors.textPrimary,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'Describe your changes...',
                hintStyle: const TextStyle(color: VioColors.textTertiary),
                filled: true,
                fillColor: VioColors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: VioColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: VioColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
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
          onPressed: () {
            if (_titleController.text.isNotEmpty) {
              widget.onCreatePR(
                _titleController.text,
                _descriptionController.text.isNotEmpty
                    ? _descriptionController.text
                    : null,
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: VioColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Create Pull Request'),
        ),
      ],
    );
  }
}
