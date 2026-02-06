import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Icon definitions for Vio design system.
/// Uses SVG icons from Penpot design system.
class VioIcons {
  VioIcons._();

  static const String _basePath = 'assets/icons';

  // Transform icons
  static const String rotation = '$_basePath/rotation.svg';
  static const String cornerRadius = '$_basePath/corner-radius.svg';
  static const String sizeHorizontal = '$_basePath/size-horizontal.svg';
  static const String sizeVertical = '$_basePath/size-vertical.svg';

  // Effects icons
  static const String dropShadow = '$_basePath/drop-shadow.svg';
  static const String innerShadow = '$_basePath/inner-shadow.svg';

  // Stroke icons
  static const String strokeSize = '$_basePath/stroke-size.svg';

  // Alignment icons
  static const String alignLeft = '$_basePath/align-left.svg';
  static const String alignHorizontalCenter =
      '$_basePath/align-horizontal-center.svg';
  static const String alignRight = '$_basePath/align-right.svg';
  static const String alignTop = '$_basePath/align-top.svg';
  static const String alignVerticalCenter =
      '$_basePath/align-vertical-center.svg';
  static const String alignBottom = '$_basePath/align-bottom.svg';

  // Flip icons
  static const String flipHorizontal = '$_basePath/flip-horizontal.svg';
  static const String flipVertical = '$_basePath/flip-vertical.svg';

  // Lock icons
  static const String lock = '$_basePath/lock.svg';
  static const String unlock = '$_basePath/unlock.svg';

  // Visibility icons
  static const String eye = '$_basePath/eye.svg';
  static const String eyeOff = '$_basePath/eye-off.svg';

  // Action icons
  static const String add = '$_basePath/add.svg';
  static const String remove = '$_basePath/remove.svg';
  static const String close = '$_basePath/close.svg';

  // Fill and stroke
  static const String fill = '$_basePath/fill.svg';
  static const String stroke = '$_basePath/stroke.svg';
}

/// A widget that displays a Vio icon from SVG.
class VioIcon extends StatelessWidget {
  const VioIcon(this.assetPath, {super.key, this.size = 16, this.color});

  /// The path to the SVG asset.
  final String assetPath;

  /// The size of the icon (width and height).
  final double size;

  /// The color to apply to the icon. If null, uses the current icon theme color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? IconTheme.of(context).color ?? Colors.white;

    return SvgPicture.asset(
      assetPath,
      package: 'vio_ui_kit',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
    );
  }
}

/// An icon button that uses Vio SVG icons.
class VioSvgIconButton extends StatelessWidget {
  const VioSvgIconButton({
    required this.assetPath, required this.onPressed, super.key,
    this.size = 16,
    this.buttonSize = 28,
    this.color,
    this.tooltip,
    this.isSelected = false,
  });

  /// The path to the SVG asset.
  final String assetPath;

  /// Called when the button is pressed.
  final VoidCallback? onPressed;

  /// The size of the icon.
  final double size;

  /// The size of the button (touchable area).
  final double buttonSize;

  /// The color to apply to the icon.
  final Color? color;

  /// Optional tooltip text.
  final String? tooltip;

  /// Whether the button is in selected state.
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ??
        (isSelected
            ? Theme.of(context).colorScheme.primary
            : Colors.white.withValues(alpha: 0.7));

    Widget button = SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(
          minWidth: buttonSize,
          minHeight: buttonSize,
        ),
        style: IconButton.styleFrom(
          backgroundColor: isSelected
              ? Colors.white.withValues(alpha: 0.1)
              : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        icon: VioIcon(assetPath, size: size, color: effectiveColor),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip, child: button);
    }

    return button;
  }
}
