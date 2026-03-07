import 'package:flutter/material.dart';

import '../theme/vio_spacing.dart';
import '../theme/vio_typography.dart';

/// Vio Design System Panel - Container for sidebar sections
class VioPanel extends StatelessWidget {
  final String? title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets? padding;
  final bool collapsible;
  final bool initiallyExpanded;
  final bool? isExpanded;
  final ValueChanged<bool>? onExpansionChanged;

  const VioPanel({
    required this.child,
    super.key,
    this.title,
    this.trailing,
    this.padding,
    this.collapsible = false,
    this.initiallyExpanded = true,
    this.isExpanded,
    this.onExpansionChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (collapsible) {
      return _CollapsiblePanel(
        title: title,
        trailing: trailing,
        padding: padding,
        initiallyExpanded: initiallyExpanded,
        isExpanded: isExpanded,
        onExpansionChanged: onExpansionChanged,
        child: child,
      );
    }

    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.25))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) _buildHeader(cs),
          Padding(
            padding: padding ?? const EdgeInsets.all(VioSpacing.panelPadding),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VioSpacing.panelPadding,
        VioSpacing.panelPadding,
        VioSpacing.panelPadding,
        VioSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title!,
              style: VioTypography.titleSmall.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _CollapsiblePanel extends StatefulWidget {
  final String? title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets? padding;
  final bool initiallyExpanded;
  final bool? isExpanded;
  final ValueChanged<bool>? onExpansionChanged;

  const _CollapsiblePanel({
    required this.child,
    required this.initiallyExpanded,
    this.title,
    this.trailing,
    this.padding,
    this.isExpanded,
    this.onExpansionChanged,
  });

  @override
  State<_CollapsiblePanel> createState() => _CollapsiblePanelState();
}

class _CollapsiblePanelState extends State<_CollapsiblePanel>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _controller;
  late Animation<double> _heightFactor;
  late Animation<double> _iconRotation;

  bool get _isControlled => widget.isExpanded != null;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded ?? widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _heightFactor = _controller.drive(CurveTween(curve: Curves.easeInOut));
    _iconRotation = _controller.drive(
      Tween(begin: 0.0, end: 0.5).chain(CurveTween(curve: Curves.easeInOut)),
    );

    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _CollapsiblePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isControlled && widget.isExpanded != oldWidget.isExpanded) {
      _updateExpanded(widget.isExpanded!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    final nextValue = !_isExpanded;
    _updateExpanded(nextValue);
    widget.onExpansionChanged?.call(nextValue);
  }

  void _updateExpanded(bool value) {
    setState(() {
      _isExpanded = value;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.25))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(cs),
          ClipRect(
            child: AnimatedBuilder(
              animation: _heightFactor,
              builder: (context, child) {
                return Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _heightFactor.value,
                  child: child,
                );
              },
              child: Padding(
                padding:
                    widget.padding ??
                    const EdgeInsets.all(VioSpacing.panelPadding),
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return InkWell(
      onTap: _toggle,
      child: Padding(
        padding: const EdgeInsets.all(VioSpacing.panelPadding),
        child: Row(
          children: [
            RotationTransition(
              turns: _iconRotation,
              child: Icon(
                Icons.expand_more,
                size: VioSpacing.iconSm,
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(width: VioSpacing.xs),
            Expanded(
              child: Text(
                widget.title ?? '',
                style: VioTypography.titleSmall.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                ),
              ),
            ),
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
      ),
    );
  }
}

/// Section divider within a panel
class VioPanelDivider extends StatelessWidget {
  const VioPanelDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: VioSpacing.sm),
      child: Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.25)),
    );
  }
}
