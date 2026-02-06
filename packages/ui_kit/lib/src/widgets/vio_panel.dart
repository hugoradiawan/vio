import 'package:flutter/material.dart';

import '../theme/vio_colors.dart';
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

  const VioPanel({
    required this.child, super.key,
    this.title,
    this.trailing,
    this.padding,
    this.collapsible = false,
    this.initiallyExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    if (collapsible) {
      return _CollapsiblePanel(
        title: title,
        trailing: trailing,
        padding: padding,
        initiallyExpanded: initiallyExpanded,
        child: child,
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: VioColors.surface,
        border: Border(bottom: BorderSide(color: VioColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) _buildHeader(),
          Padding(
            padding: padding ?? const EdgeInsets.all(VioSpacing.panelPadding),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
                color: VioColors.textSecondary,
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

  const _CollapsiblePanel({
    required this.child, required this.initiallyExpanded, this.title,
    this.trailing,
    this.padding,
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

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: VioColors.surface,
        border: Border(bottom: BorderSide(color: VioColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
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

  Widget _buildHeader() {
    return InkWell(
      onTap: _toggle,
      child: Padding(
        padding: const EdgeInsets.all(VioSpacing.panelPadding),
        child: Row(
          children: [
            RotationTransition(
              turns: _iconRotation,
              child: const Icon(
                Icons.expand_more,
                size: VioSpacing.iconSm,
                color: VioColors.textTertiary,
              ),
            ),
            const SizedBox(width: VioSpacing.xs),
            Expanded(
              child: Text(
                widget.title ?? '',
                style: VioTypography.titleSmall.copyWith(
                  color: VioColors.textSecondary,
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
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: VioSpacing.sm),
      child: Divider(height: 1, color: VioColors.borderSubtle),
    );
  }
}
