import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/version_control_bloc.dart';

/// A lightweight dialog for committing changes before a branch switch.
///
/// Shows a commit message text field and triggers a commit-then-switch flow
/// via [CommitAndSwitchRequested].
class CommitDialog extends StatefulWidget {
  const CommitDialog({
    required this.targetBranchId,
    required this.targetBranchName,
    super.key,
  });

  /// The branch to switch to after committing.
  final String targetBranchId;

  /// Display name of the target branch.
  final String targetBranchName;

  @override
  State<CommitDialog> createState() => _CommitDialogState();
}

class _CommitDialogState extends State<CommitDialog> {
  final _messageController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus the message field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onCommit() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    Navigator.of(context).pop();
    context.read<VersionControlBloc>().add(
          CommitAndSwitchRequested(
            message: message,
            targetBranchId: widget.targetBranchId,
          ),
        );
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
          Icon(Icons.save_outlined, color: cs.primary, size: 24),
          const SizedBox(width: 12),
          Text(
            'Commit Changes',
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
            Text(
              'Commit your changes before switching to "${widget.targetBranchName}".',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              focusNode: _focusNode,
              maxLines: 3,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Commit message...',
                hintStyle: TextStyle(color: cs.onSurfaceVariant),
                filled: true,
                fillColor: cs.surface,
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
                contentPadding: const EdgeInsets.all(12),
              ),
              onSubmitted: (_) => _onCommit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            context
                .read<VersionControlBloc>()
                .add(const BranchSwitchCanceled());
          },
          child: Text(
            'Cancel',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _messageController,
          builder: (context, value, child) {
            final hasMessage = value.text.trim().isNotEmpty;
            return ElevatedButton(
              onPressed: hasMessage ? _onCommit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    hasMessage ? cs.primary : cs.outline,
                foregroundColor: Colors.white,
              ),
              child: const Text('Commit & Switch'),
            );
          },
        ),
      ],
    );
  }
}
