import 'package:flutter/material.dart';

import '../theme/vio_colors.dart';
import '../theme/vio_spacing.dart';
import '../theme/vio_typography.dart';

/// Vio Design System Text Field
class VioTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final Widget? prefix;
  final Widget? suffix;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final FocusNode? focusNode;
  final bool autofocus;

  const VioTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.prefix,
    this.suffix,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: VioTypography.labelMedium.copyWith(
              color: VioColors.textSecondary,
            ),
          ),
          const SizedBox(height: VioSpacing.xs),
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          enabled: enabled,
          readOnly: readOnly,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          onTap: onTap,
          autofocus: autofocus,
          style: VioTypography.bodyMedium,
          cursorColor: VioColors.primary,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: VioSpacing.iconMd)
                : prefix,
            suffixIcon: _buildSuffix(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: VioSpacing.inputPaddingH,
              vertical: VioSpacing.inputPaddingV,
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildSuffix() {
    if (suffixIcon != null) {
      return IconButton(
        icon: Icon(suffixIcon, size: VioSpacing.iconMd),
        onPressed: onSuffixTap,
        splashRadius: 16,
      );
    }
    return suffix;
  }
}

/// Numeric text field for coordinate/dimension input
class VioNumericField extends StatefulWidget {
  final double? value;
  final String? label;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int decimals;
  final bool enabled;

  const VioNumericField({
    super.key,
    this.value,
    this.label,
    this.onChanged,
    this.min = double.negativeInfinity,
    this.max = double.infinity,
    this.decimals = 0,
    this.enabled = true,
  });

  @override
  State<VioNumericField> createState() => _VioNumericFieldState();
}

class _VioNumericFieldState extends State<VioNumericField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatValue(widget.value));
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(VioNumericField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && !_focusNode.hasFocus) {
      _controller.text = _formatValue(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  String _formatValue(double? value) {
    if (value == null) return '';
    if (widget.decimals == 0) return value.round().toString();
    return value.toStringAsFixed(widget.decimals);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _commitValue();
    }
  }

  void _commitValue() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _controller.text = _formatValue(widget.value);
      return;
    }

    final parsed = double.tryParse(text);
    if (parsed != null) {
      final clamped = parsed.clamp(widget.min, widget.max);
      _controller.text = _formatValue(clamped);
      widget.onChanged?.call(clamped);
    } else {
      _controller.text = _formatValue(widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        textAlign: TextAlign.center,
        style: VioTypography.bodyMedium.copyWith(
          color: VioColors.textPrimary,
        ),
        onSubmitted: (_) => _commitValue(),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: VioSpacing.sm,
            vertical: 6,
          ),
          suffixText: widget.label,
          suffixStyle: VioTypography.caption.copyWith(
            color: VioColors.textTertiary,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
            borderSide: const BorderSide(color: VioColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
            borderSide: const BorderSide(color: VioColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
            borderSide: const BorderSide(color: VioColors.primary),
          ),
          filled: true,
          fillColor: VioColors.surfaceElevated,
        ),
      ),
    );
  }
}
