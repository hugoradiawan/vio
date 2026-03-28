import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart' show VioIconButton;

import '../../../../gen/vio/v1/branch.pb.dart' as branch_pb;
import '../../bloc/version_control_bloc.dart';
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
        final cs = Theme.of(context).colorScheme;

        return Container(
          decoration: BoxDecoration(color: cs.surface),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search bar
              _buildSearchBar(),

              // Branch list
              Expanded(
                child: isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: cs.primary,
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

  Widget _buildSearchBar() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search branches...',
                hintStyle: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 24, minHeight: 16),
                // suffixIcon: _searchQuery.isNotEmpty
                //     ? IconButton(
                //         onPressed: () {
                //           _searchController.clear();
                //           setState(() {
                //             _searchQuery = '';
                //           });
                //         },
                //         icon: const Icon(Icons.clear, size: 16),
                //         color: cs.onSurfaceVariant,
                //       )
                //     : null,
                filled: true,
                fillColor: cs.surfaceContainerHigh,
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
                  borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.25)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: cs.primary),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
                        if (_searchQuery.isNotEmpty)
                VioIconButton(
                  icon: Icons.close,
                  size: 24,
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final cs = Theme.of(context).colorScheme;
    if (_searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No branches matching "$_searchQuery"',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 48,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No branches found',
            style: TextStyle(
              color: cs.onSurfaceVariant,
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
    List<branch_pb.Branch> branches,
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

  List<branch_pb.Branch> _filterBranches(
    List<branch_pb.Branch> branches,
    String query,
  ) {
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

  void _showCreatePRDialog(
    BuildContext context,
    branch_pb.Branch sourceBranch,
    branch_pb.Branch targetBranch,
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

  final branch_pb.Branch branch;
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
    final cs = Theme.of(context).colorScheme;
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
                ? cs.primary.withAlpha(26)
                : _isHovered
                    ? cs.surfaceContainerHigh
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: widget.isCurrentBranch
                ? Border.all(color: cs.primary.withAlpha(77))
                : null,
          ),
          child: Row(
            children: [
              // Branch icon
              Icon(
                widget.isCurrentBranch ? Icons.check_circle : Icons.merge,
                size: 16,
                color:
                    widget.isCurrentBranch ? cs.primary : cs.onSurfaceVariant,
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
                        color:
                            widget.isCurrentBranch ? cs.primary : cs.onSurface,
                        fontSize: 13,
                        fontWeight: widget.isCurrentBranch
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.branch.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.branch.description,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
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
                    color: cs.primary.withAlpha(51),
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
                const SizedBox(width: 4),
              ],
              if (widget.branch.isProtected) ...[
                Icon(
                  Icons.lock,
                  size: 12,
                  color: cs.onSurfaceVariant,
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
                    color: cs.error,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final cs = Theme.of(context).colorScheme;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: cs.outline),
      ),
      items: [
        if (!widget.isCurrentBranch)
          PopupMenuItem<String>(
            value: 'switch',
            child: Row(
              children: [
                Icon(
                  Icons.swap_horiz,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Switch to branch',
                  style: TextStyle(fontSize: 13, color: cs.onSurface),
                ),
              ],
            ),
          ),
        if (!widget.branch.isDefault)
          PopupMenuItem<String>(
            value: 'create_pr',
            child: Row(
              children: [
                Icon(
                  Icons.call_merge,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Create Pull Request',
                  style: TextStyle(fontSize: 13, color: cs.onSurface),
                ),
              ],
            ),
          ),
        PopupMenuItem<String>(
          value: 'compare',
          child: Row(
            children: [
              Icon(
                Icons.compare_arrows,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'Compare with default',
                style: TextStyle(fontSize: 13, color: cs.onSurface),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'Branch settings',
                style: TextStyle(fontSize: 13, color: cs.onSurface),
              ),
            ],
          ),
        ),
        if (!widget.branch.isDefault && !widget.branch.isProtected)
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 16, color: cs.error),
                const SizedBox(width: 8),
                Text(
                  'Delete branch',
                  style: TextStyle(fontSize: 13, color: cs.error),
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
            color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
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

  final branch_pb.Branch sourceBranch;
  final branch_pb.Branch targetBranch;
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
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outline),
      ),
      title: Row(
        children: [
          Icon(Icons.call_merge, color: cs.primary, size: 24),
          const SizedBox(width: 12),
          Text(
            'Create Pull Request',
            style: TextStyle(
              color: cs.onSurface,
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
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'From',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          widget.sourceBranch.name,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: cs.onSurfaceVariant,
                    size: 16,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Into',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          widget.targetBranch.name,
                          style: TextStyle(
                            color: cs.onSurface,
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
            Text(
              'Title',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _titleController,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'Pull request title',
                hintStyle: TextStyle(color: cs.onSurfaceVariant),
                filled: true,
                fillColor: cs.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: cs.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: cs.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: cs.primary),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Description field
            Text(
              'Description (optional)',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'Describe your changes...',
                hintStyle: TextStyle(color: cs.onSurfaceVariant),
                filled: true,
                fillColor: cs.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: cs.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: cs.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: cs.primary),
                ),
              ),
            ),
          ],
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
            backgroundColor: cs.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Create Pull Request'),
        ),
      ],
    );
  }
}
