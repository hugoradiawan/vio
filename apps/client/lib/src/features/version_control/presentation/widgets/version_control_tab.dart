import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../bloc/version_control_bloc.dart';
import 'commit_history_list.dart';
import 'commit_panel.dart';

/// Main version control tab content for the left panel
class VersionControlTab extends StatelessWidget {
  const VersionControlTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VersionControlBloc, VersionControlState>(
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
            const CommitPanel(),

            // Divider with "History" label
            _SectionHeader(
              title: 'History',
              trailing: _RefreshButton(
                isLoading: state.status == VersionControlStatus.loading,
                onRefresh: () {
                  context
                      .read<VersionControlBloc>()
                      .add(const CommitsRefreshRequested());
                },
              ),
            ),

            // Commit history list
            const Expanded(
              child: CommitHistoryList(),
            ),
          ],
        );
      },
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

/// Section header with title and optional trailing widget
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

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
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: VioColors.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
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
