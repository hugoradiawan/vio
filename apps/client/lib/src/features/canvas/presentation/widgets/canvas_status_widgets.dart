import 'package:flutter/material.dart';
import 'package:vio_client/src/core/core.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

class CanvasCoordinatesDisplay extends StatelessWidget {
  const CanvasCoordinatesDisplay({
    required this.pointer,
    super.key,
  });

  final Offset? pointer;

  @override
  Widget build(BuildContext context) {
    if (pointer == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VioSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
      ),
      child: Text(
        'X: ${pointer!.dx.toStringAsFixed(0)}  Y: ${pointer!.dy.toStringAsFixed(0)}',
        style: VioTypography.caption.copyWith(
          color: cs.onSurfaceVariant,
          fontFamily: 'monospace',
          fontSize: 10,
        ),
      ),
    );
  }
}

class CanvasSyncStatusIndicator extends StatelessWidget {
  const CanvasSyncStatusIndicator({
    required this.syncStatus,
    super.key,
    this.syncError,
  });

  final SyncStatus syncStatus;
  final String? syncError;

  @override
  Widget build(BuildContext context) {
    if (syncStatus == SyncStatus.idle) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final (icon, color, label) = _getStatusInfo(cs);

    return Tooltip(
      message: syncError ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: VioSpacing.xs,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (syncStatus == SyncStatus.syncing)
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            else
              Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: VioTypography.caption.copyWith(
                color: color,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color, String) _getStatusInfo(ColorScheme cs) =>
      switch (syncStatus) {
        SyncStatus.idle => (
            Icons.cloud_off_outlined,
            cs.onSurfaceVariant,
            'Offline'
          ),
        SyncStatus.loading => (
            Icons.cloud_download_outlined,
            cs.primary,
            'Loading...'
          ),
        SyncStatus.pending => (
            Icons.cloud_upload_outlined,
            VioColors.warning,
            'Pending'
          ),
        SyncStatus.syncing => (
            Icons.cloud_sync_outlined,
            cs.primary,
            'Syncing...'
          ),
        SyncStatus.synced => (
            Icons.cloud_done_outlined,
            VioColors.success,
            'Synced'
          ),
        SyncStatus.error => (Icons.cloud_off_outlined, cs.error, 'Sync Error'),
      };
}
