import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../../core/core.dart';
import '../../../../gen/vio/v1/branch.pb.dart' as branch_pb;
import '../../bloc/version_control_bloc.dart';

/// Dialog for viewing and editing branch settings
///
/// Features:
/// - View branch details (name, description, created date, creator)
/// - Toggle protection status (if authorized)
/// - View head commit info
/// - Rename branch (if not protected)
/// - Set as default branch
class BranchSettingsDialog extends StatefulWidget {
  const BranchSettingsDialog({
    required this.branch,
    super.key,
  });

  final branch_pb.Branch branch;

  @override
  State<BranchSettingsDialog> createState() => _BranchSettingsDialogState();
}

class _BranchSettingsDialogState extends State<BranchSettingsDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.branch.name);
    _descriptionController = TextEditingController(
      text: widget.branch.description,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _checkForChanges() {
    final hasNameChange = _nameController.text != widget.branch.name;
    final hasDescriptionChange =
        _descriptionController.text != widget.branch.description;

    setState(() {
      _hasChanges = hasNameChange || hasDescriptionChange;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VersionControlBloc, VersionControlState>(
      builder: (context, state) {
        final isCurrentBranch = widget.branch.id == state.currentBranchId;
        final canEdit = !widget.branch.isProtected;

        return AlertDialog(
          backgroundColor: VioColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: VioColors.border),
          ),
          title: Row(
            children: [
              const Icon(Icons.settings, color: VioColors.primary, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Branch Settings',
                style: TextStyle(
                  color: VioColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Status badges
              if (widget.branch.isDefault) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: VioColors.primary.withAlpha(51),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'default',
                    style: TextStyle(
                      color: VioColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              if (widget.branch.isProtected) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: VioColors.warning.withAlpha(51),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, size: 10, color: VioColors.warning),
                      SizedBox(width: 2),
                      Text(
                        'protected',
                        style: TextStyle(
                          color: VioColors.warning,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Branch info section
                  _buildInfoSection(),

                  const SizedBox(height: 20),
                  const Divider(color: VioColors.border),
                  const SizedBox(height: 20),

                  // Edit section (if allowed)
                  if (canEdit) ...[
                    _buildEditSection(),
                    const SizedBox(height: 20),
                    const Divider(color: VioColors.border),
                    const SizedBox(height: 20),
                  ],

                  // Actions section
                  _buildActionsSection(context, state, isCurrentBranch),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                _hasChanges ? 'Discard' : 'Close',
                style: const TextStyle(color: VioColors.textSecondary),
              ),
            ),
            if (_hasChanges && canEdit)
              ElevatedButton(
                onPressed: () {
                  context.read<VersionControlBloc>().add(
                        BranchUpdateRequested(
                          branchId: widget.branch.id,
                          name: _nameController.text.trim(),
                          description:
                              _descriptionController.text.trim().isEmpty
                                  ? null
                                  : _descriptionController.text.trim(),
                        ),
                      );
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Branch updated'),
                      backgroundColor: VioColors.success,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: VioColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save Changes'),
              ),
          ],
        );
      },
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BRANCH INFORMATION',
          style: TextStyle(
            color: VioColors.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),

        // Branch name
        _InfoRow(
          label: 'Name',
          value: widget.branch.name,
          icon: Icons.merge,
        ),

        // Head commit
        if (widget.branch.headCommitId.isNotEmpty)
          _InfoRow(
            label: 'Head Commit',
            value: widget.branch.headCommitId.substring(0, 8),
            icon: Icons.commit,
            valueColor: VioColors.textTertiary,
            monospace: true,
          ),

        // Created date
        if (widget.branch.createdAtDateTime != null)
          _InfoRow(
            label: 'Created',
            value: _formatDate(widget.branch.createdAtDateTime!),
            icon: Icons.calendar_today,
          ),
      ],
    );
  }

  Widget _buildEditSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'EDIT BRANCH',
          style: TextStyle(
            color: VioColors.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),

        // Name field
        const Text(
          'Name',
          style: TextStyle(
            color: VioColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _nameController,
          onChanged: (_) => _checkForChanges(),
          style: const TextStyle(
            color: VioColors.textPrimary,
            fontSize: 13,
          ),
          decoration: InputDecoration(
            hintText: 'Branch name',
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
          'Description',
          style: TextStyle(
            color: VioColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _descriptionController,
          onChanged: (_) => _checkForChanges(),
          maxLines: 2,
          style: const TextStyle(
            color: VioColors.textPrimary,
            fontSize: 13,
          ),
          decoration: InputDecoration(
            hintText: 'Optional description...',
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
    );
  }

  Widget _buildActionsSection(
    BuildContext context,
    VersionControlState state,
    bool isCurrentBranch,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ACTIONS',
          style: TextStyle(
            color: VioColors.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),

        // Compare with default
        if (!widget.branch.isDefault)
          _ActionButton(
            icon: Icons.compare_arrows,
            label: 'Compare with default branch',
            onTap: () {
              final defaultBranch = state.defaultBranch;
              if (defaultBranch != null) {
                context.read<VersionControlBloc>().add(
                      BranchCompareRequested(
                        baseBranchId: defaultBranch.id,
                        headBranchId: widget.branch.id,
                      ),
                    );
                Navigator.of(context).pop();
              }
            },
          ),

        // Create PR
        if (!widget.branch.isDefault)
          _ActionButton(
            icon: Icons.call_merge,
            label: 'Create pull request to default',
            onTap: () {
              final defaultBranch = state.defaultBranch;
              if (defaultBranch != null) {
                Navigator.of(context).pop();
                // Trigger PR creation (handled by parent)
                context.read<VersionControlBloc>().add(
                      PullRequestCreateRequested(
                        sourceBranchId: widget.branch.id,
                        targetBranchId: defaultBranch.id,
                        title:
                            'Merge ${widget.branch.name} into ${defaultBranch.name}',
                      ),
                    );
              }
            },
          ),

        // Delete branch
        if (!widget.branch.isDefault &&
            !widget.branch.isProtected &&
            !isCurrentBranch)
          _ActionButton(
            icon: Icons.delete_outline,
            label: 'Delete this branch',
            color: VioColors.error,
            onTap: () {
              Navigator.of(context).pop();
              context.read<VersionControlBloc>().add(
                    BranchDeleteRequested(branchId: widget.branch.id),
                  );
            },
          ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

/// Info row widget for displaying branch details
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
    this.monospace = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: VioColors.textTertiary,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: VioColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? VioColors.textPrimary,
                fontSize: 13,
                fontFamily: monospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Action button widget for branch settings
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? VioColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: effectiveColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: effectiveColor,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: VioColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to show the branch settings dialog
void showBranchSettingsDialog(BuildContext context, branch_pb.Branch branch) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => BranchSettingsDialog(branch: branch),
  );
}
