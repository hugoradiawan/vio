import 'package:flutter/material.dart';
import 'package:vio_core/vio_core.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../../gen/vio/v1/common.pb.dart' as common_pb;
import '../../../../gen/vio/v1/common.pbenum.dart' as common_enum;

/// Dialog for resolving merge conflicts with visual diff preview
/// Option B: Visual side-by-side shape preview
class ConflictResolutionDialog extends StatefulWidget {
  const ConflictResolutionDialog({
    required this.conflicts,
    required this.sourceBranchName,
    required this.targetBranchName,
    required this.onResolve,
    super.key,
  });

  final List<common_pb.ShapeConflict> conflicts;
  final String sourceBranchName;
  final String targetBranchName;
  final void Function(List<common_pb.ConflictResolution> resolutions) onResolve;

  @override
  State<ConflictResolutionDialog> createState() =>
      _ConflictResolutionDialogState();
}

class _ConflictResolutionDialogState extends State<ConflictResolutionDialog> {
  late Map<String, common_enum.ResolutionChoice> _resolutions;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize all resolutions to use source by default
    _resolutions = {
      for (final conflict in widget.conflicts)
        conflict.shapeId: common_enum.ResolutionChoice.RESOLUTION_CHOICE_SOURCE,
    };
  }

  bool get _allResolved => _resolutions.values.every(
        (choice) =>
            choice != common_enum.ResolutionChoice.RESOLUTION_CHOICE_SOURCE &&
                choice !=
                    common_enum.ResolutionChoice.RESOLUTION_CHOICE_TARGET ||
            _resolutions.values.isNotEmpty,
      );

  common_pb.ShapeConflict get _currentConflict =>
      widget.conflicts[_currentIndex];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            _DialogHeader(
              conflictCount: widget.conflicts.length,
              currentIndex: _currentIndex,
              onClose: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),

            // Navigation tabs
            _ConflictNavigator(
              conflicts: widget.conflicts,
              currentIndex: _currentIndex,
              resolutions: _resolutions,
              onSelectConflict: (index) {
                setState(() => _currentIndex = index);
              },
            ),
            const SizedBox(height: 16),

            // Main content - side by side diff
            Expanded(
              child: _ConflictDiffView(
                conflict: _currentConflict,
                sourceBranchName: widget.sourceBranchName,
                targetBranchName: widget.targetBranchName,
                resolution: _resolutions[_currentConflict.shapeId]!,
                onResolutionChanged: (choice) {
                  setState(() {
                    _resolutions[_currentConflict.shapeId] = choice;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // Footer with actions
            _DialogFooter(
              canResolve: _allResolved,
              onCancel: () => Navigator.of(context).pop(),
              onResolve: () {
                final resolutions = <common_pb.ConflictResolution>[];
                for (final conflict in widget.conflicts) {
                  final choice = _resolutions[conflict.shapeId]!;
                  // Generate per-property resolutions from per-shape choice
                  for (final prop in conflict.propertyConflicts) {
                    resolutions.add(
                      common_pb.ConflictResolution(
                        shapeId: conflict.shapeId,
                        propertyName: prop.propertyName,
                        choice: choice,
                      ),
                    );
                  }
                }
                widget.onResolve(resolutions);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog header with title and close button
class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.conflictCount,
    required this.currentIndex,
    required this.onClose,
  });

  final int conflictCount;
  final int currentIndex;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        const Icon(
          Icons.warning_amber,
          color: VioColors.warning,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resolve Conflicts',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${currentIndex + 1} of $conflictCount conflict${conflictCount > 1 ? 's' : ''}',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: Icon(
            Icons.close,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Conflict navigation tabs
class _ConflictNavigator extends StatelessWidget {
  const _ConflictNavigator({
    required this.conflicts,
    required this.currentIndex,
    required this.resolutions,
    required this.onSelectConflict,
  });

  final List<common_pb.ShapeConflict> conflicts;
  final int currentIndex;
  final Map<String, common_enum.ResolutionChoice> resolutions;
  final void Function(int index) onSelectConflict;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(4),
        itemCount: conflicts.length,
        itemBuilder: (context, index) {
          final conflict = conflicts[index];
          final isSelected = index == currentIndex;
          final isResolved = resolutions[conflict.shapeId] != null;

          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: InkWell(
              onTap: () => onSelectConflict(index),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isSelected ? cs.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      isResolved ? Icons.check_circle : Icons.radio_button_off,
                      size: 14,
                      color: isSelected
                          ? Colors.white
                          : isResolved
                              ? VioColors.success
                              : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      conflict.shapeName,
                      style: TextStyle(
                        color: isSelected ? Colors.white : cs.onSurface,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Main diff view with side-by-side comparison
class _ConflictDiffView extends StatelessWidget {
  const _ConflictDiffView({
    required this.conflict,
    required this.sourceBranchName,
    required this.targetBranchName,
    required this.resolution,
    required this.onResolutionChanged,
  });

  final common_pb.ShapeConflict conflict;
  final String sourceBranchName;
  final String targetBranchName;
  final common_enum.ResolutionChoice resolution;
  final void Function(common_enum.ResolutionChoice) onResolutionChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Source (incoming) version
        Expanded(
          child: _ShapeVersionPanel(
            title: sourceBranchName,
            subtitle: 'Incoming changes',
            isSelected: resolution ==
                common_enum.ResolutionChoice.RESOLUTION_CHOICE_SOURCE,
            color: Theme.of(context).colorScheme.primary,
            shapeData:
                null, // Proto ShapeConflict doesn't carry full shape objects
            propertyConflicts: conflict.propertyConflicts,
            showSource: true,
            onSelect: () => onResolutionChanged(
                common_enum.ResolutionChoice.RESOLUTION_CHOICE_SOURCE,),
          ),
        ),
        const SizedBox(width: 16),

        // Target (current) version
        Expanded(
          child: _ShapeVersionPanel(
            title: targetBranchName,
            subtitle: 'Current version',
            isSelected: resolution ==
                common_enum.ResolutionChoice.RESOLUTION_CHOICE_TARGET,
            color: VioColors.warning,
            shapeData:
                null, // Proto ShapeConflict doesn't carry full shape objects
            propertyConflicts: conflict.propertyConflicts,
            showSource: false,
            onSelect: () => onResolutionChanged(
                common_enum.ResolutionChoice.RESOLUTION_CHOICE_TARGET,),
          ),
        ),
      ],
    );
  }
}

/// Panel showing one version of the shape
class _ShapeVersionPanel extends StatelessWidget {
  const _ShapeVersionPanel({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.color,
    required this.shapeData,
    required this.propertyConflicts,
    required this.showSource,
    required this.onSelect,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final Color color;
  final Shape? shapeData;
  final List<common_pb.PropertyConflict> propertyConflicts;
  final bool showSource;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : cs.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? color.withAlpha(26) : Colors.transparent,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_off,
                    size: 18,
                    color: isSelected ? color : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'SELECTED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Shape preview
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _ShapePreview(
                  shapeData: shapeData,
                  accentColor: color,
                ),
              ),
            ),

            // Property conflicts
            if (propertyConflicts.isNotEmpty)
              _PropertyConflictsList(
                conflicts: propertyConflicts,
                showSource: showSource,
                accentColor: color,
              ),
          ],
        ),
      ),
    );
  }
}

/// Visual preview of a shape (simplified representation)
class _ShapePreview extends StatelessWidget {
  const _ShapePreview({
    required this.shapeData,
    required this.accentColor,
  });

  final Shape? shapeData;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    if (shapeData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_outline,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              'Shape deleted',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    final shape = shapeData!;
    final type = shape.type.name;
    final x = shape.x;
    final y = shape.y;
    final width = shape.width;
    final height = shape.height;

    // Get fill color
    Color fillColor = accentColor.withAlpha(51);
    if (shape.fills.isNotEmpty) {
      fillColor = Color(shape.fills.first.color);
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Stack(
        children: [
          // Grid background
          CustomPaint(
            size: Size.infinite,
            painter: _GridPainter(
              gridColor: Theme.of(context).colorScheme.outline,
            ),
          ),

          // Shape representation
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Scale shape to fit preview
                final scale =
                    (constraints.maxWidth / (width + 40)).clamp(0.1, 2.0);
                final scaledWidth = width * scale;
                final scaledHeight = height * scale;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Shape visualization
                    Container(
                      width: scaledWidth.clamp(40.0, constraints.maxWidth - 20),
                      height:
                          scaledHeight.clamp(40.0, constraints.maxHeight - 80),
                      decoration: BoxDecoration(
                        color: fillColor,
                        borderRadius: type == 'rectangle'
                            ? BorderRadius.circular(4)
                            : null,
                        shape: type == 'ellipse'
                            ? BoxShape.circle
                            : BoxShape.rectangle,
                        border: Border.all(
                          color: accentColor,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          type.toUpperCase(),
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Dimensions
                    Text(
                      '${width.toStringAsFixed(0)} × ${height.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'at (${x.toStringAsFixed(0)}, ${y.toStringAsFixed(0)})',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid painter for shape preview background
class _GridPainter extends CustomPainter {
  const _GridPainter({required this.gridColor});
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor.withAlpha(128)
      ..strokeWidth = 0.5;

    const gridSize = 20.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.gridColor != gridColor;
}

/// List of property-level conflicts
class _PropertyConflictsList extends StatelessWidget {
  const _PropertyConflictsList({
    required this.conflicts,
    required this.showSource,
    required this.accentColor,
  });

  final List<common_pb.PropertyConflict> conflicts;
  final bool showSource;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(10),
        ),
        border: Border(
          top: BorderSide(color: cs.outline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONFLICTING PROPERTIES',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          ...conflicts.take(5).map((conflict) {
            final value =
                showSource ? conflict.sourceValue : conflict.targetValue;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    conflict.propertyName,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ':',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _formatValue(value),
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (conflicts.length > 5)
            Text(
              '... and ${conflicts.length - 5} more',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'null';
    if (value is double) return value.toStringAsFixed(2);
    if (value is Map || value is List) return value.toString().substring(0, 50);
    return value.toString();
  }
}

/// Dialog footer with action buttons
class _DialogFooter extends StatelessWidget {
  const _DialogFooter({
    required this.canResolve,
    required this.onCancel,
    required this.onResolve,
  });

  final bool canResolve;
  final VoidCallback onCancel;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: onCancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.onSurfaceVariant,
            side: BorderSide(color: cs.outline),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: canResolve ? onResolve : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: cs.surfaceContainerHigh,
            disabledForegroundColor: cs.onSurfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Apply Resolutions'),
        ),
      ],
    );
  }
}
