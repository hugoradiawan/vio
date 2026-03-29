import 'package:flutter/material.dart';

import '../theme/vio_spacing.dart';
import '../theme/vio_typography.dart';
import 'vio_icon_button.dart';

/// Compact, reusable search bar used across Vio side panels.
class VioSearchBar extends StatefulWidget {
  const VioSearchBar({
    required this.hintText,
    super.key,
    this.controller,
    this.onChanged,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.showLeadingIcon = true,
    this.showClearButton = true,
    this.alwaysShowClearButton = false,
    this.clearTooltip = 'Clear search',
    this.onClear,
    this.height = 36,
  });

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final bool showLeadingIcon;
  final bool showClearButton;
  final bool alwaysShowClearButton;
  final String clearTooltip;
  final VoidCallback? onClear;
  final double height;

  @override
  State<VioSearchBar> createState() => _VioSearchBarState();
}

class _VioSearchBarState extends State<VioSearchBar> {
  TextEditingController? _internalController;

  TextEditingController? get _controller =>
      widget.controller ?? _internalController;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = TextEditingController();
    }
    _controller?.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant VioSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      _controller?.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _internalController?.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted || !widget.showClearButton) return;
    setState(() {});
  }

  void _handleClear() {
    if (widget.onClear != null) {
      widget.onClear!();
      return;
    }

    final controller = _controller;
    if (controller == null) return;
    controller.clear();
    widget.onChanged?.call('');
  }

  bool get _shouldShowClearButton {
    if (!widget.showClearButton) return false;
    if (widget.alwaysShowClearButton) return true;
    return _controller?.text.trim().isNotEmpty ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: widget.height,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: widget.focusNode,
              autofocus: widget.autofocus,
              enabled: widget.enabled,
              style: VioTypography.body2.copyWith(color: cs.onSurface),
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                isDense: true,
                hintText: widget.hintText,
                hintStyle: VioTypography.body2.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
                  borderSide: BorderSide(
                    color: cs.outline.withValues(alpha: 0.25),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
                  borderSide: BorderSide(color: cs.primary),
                ),
                prefixIcon: widget.showLeadingIcon
                    ? Icon(
                        Icons.search,
                        size: VioSpacing.iconSm,
                        color: cs.onSurfaceVariant,
                      )
                    : null,
                prefixIconConstraints: widget.showLeadingIcon
                    ? const BoxConstraints(minWidth: 24, minHeight: 16)
                    : null,
              ),
            ),
          ),
          if (_shouldShowClearButton)
            VioIconButton(
              icon: Icons.close,
              size: 24,
              tooltip: widget.clearTooltip,
              onPressed: _handleClear,
            ),
        ],
      ),
    );
  }
}
