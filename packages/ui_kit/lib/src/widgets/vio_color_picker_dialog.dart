import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/vio_colors.dart';
import '../theme/vio_spacing.dart';
import '../theme/vio_typography.dart';

/// A full-featured color picker dialog with HSV picker, RGB/HEX inputs, and opacity slider
class VioColorPickerDialog extends StatefulWidget {
  const VioColorPickerDialog({
    required this.initialColor,
    super.key,
    this.initialOpacity = 1.0,
    this.showOpacity = true,
  });

  /// Initial color value (ARGB int)
  final int initialColor;

  /// Initial opacity (0.0 - 1.0)
  final double initialOpacity;

  /// Whether to show opacity slider
  final bool showOpacity;

  /// Show the color picker dialog and return the selected color
  static Future<ColorPickerResult?> show(
    BuildContext context, {
    required int initialColor,
    double initialOpacity = 1.0,
    bool showOpacity = true,
  }) {
    return showDialog<ColorPickerResult>(
      context: context,
      builder: (context) => VioColorPickerDialog(
        initialColor: initialColor,
        initialOpacity: initialOpacity,
        showOpacity: showOpacity,
      ),
    );
  }

  @override
  State<VioColorPickerDialog> createState() => _VioColorPickerDialogState();
}

/// Result from the color picker dialog
class ColorPickerResult {
  const ColorPickerResult({required this.color, required this.opacity});

  final int color;
  final double opacity;
}

class _VioColorPickerDialogState extends State<VioColorPickerDialog> {
  late HSVColor _hsvColor;
  late double _opacity;
  late TextEditingController _hexController;
  late TextEditingController _rController;
  late TextEditingController _gController;
  late TextEditingController _bController;

  @override
  void initState() {
    super.initState();
    final color = Color(widget.initialColor);
    _hsvColor = HSVColor.fromColor(color);
    _opacity = widget.initialOpacity;

    _hexController = TextEditingController(text: _colorToHex(color));
    _rController = TextEditingController(text: _getRed(color).toString());
    _gController = TextEditingController(text: _getGreen(color).toString());
    _bController = TextEditingController(text: _getBlue(color).toString());
  }

  @override
  void dispose() {
    _hexController.dispose();
    _rController.dispose();
    _gController.dispose();
    _bController.dispose();
    super.dispose();
  }

  /// Get red component (0-255)
  int _getRed(Color color) => (color.r * 255.0).round().clamp(0, 255);

  /// Get green component (0-255)
  int _getGreen(Color color) => (color.g * 255.0).round().clamp(0, 255);

  /// Get blue component (0-255)
  int _getBlue(Color color) => (color.b * 255.0).round().clamp(0, 255);

  String _colorToHex(Color color) {
    return '${_getRed(color).toRadixString(16).padLeft(2, '0')}'
            '${_getGreen(color).toRadixString(16).padLeft(2, '0')}'
            '${_getBlue(color).toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  void _updateFromHSV(HSVColor hsv) {
    setState(() {
      _hsvColor = hsv;
      final color = hsv.toColor();
      _hexController.text = _colorToHex(color);
      _rController.text = _getRed(color).toString();
      _gController.text = _getGreen(color).toString();
      _bController.text = _getBlue(color).toString();
    });
  }

  void _updateFromHex(String hex) {
    if (hex.length != 6) return;
    try {
      final color = Color(int.parse('FF$hex', radix: 16));
      setState(() {
        _hsvColor = HSVColor.fromColor(color);
        _rController.text = _getRed(color).toString();
        _gController.text = _getGreen(color).toString();
        _bController.text = _getBlue(color).toString();
      });
    } catch (_) {}
  }

  void _updateFromRGB() {
    final r = int.tryParse(_rController.text) ?? 0;
    final g = int.tryParse(_gController.text) ?? 0;
    final b = int.tryParse(_bController.text) ?? 0;

    final color = Color.fromARGB(
      255,
      r.clamp(0, 255),
      g.clamp(0, 255),
      b.clamp(0, 255),
    );
    setState(() {
      _hsvColor = HSVColor.fromColor(color);
      _hexController.text = _colorToHex(color);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: VioColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VioSpacing.radiusMd),
      ),
      child: SizedBox(
        width: 320,
        child: Padding(
          padding: const EdgeInsets.all(VioSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Color Picker',
                    style: VioTypography.labelLarge.copyWith(
                      color: VioColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: VioColors.textTertiary,
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: VioSpacing.md),

              // HSV Picker area
              _buildHSVPicker(),
              const SizedBox(height: VioSpacing.md),

              // Hue slider
              _buildHueSlider(),
              const SizedBox(height: VioSpacing.md),

              // Opacity slider (optional)
              if (widget.showOpacity) ...[
                _buildOpacitySlider(),
                const SizedBox(height: VioSpacing.md),
              ],

              // Color preview and inputs
              _buildColorInputs(),
              const SizedBox(height: VioSpacing.lg),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: VioTypography.bodyMedium.copyWith(
                        color: VioColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: VioSpacing.sm),
                  ElevatedButton(
                    onPressed: () {
                      final color = _hsvColor.toColor();
                      Navigator.of(context).pop(
                        ColorPickerResult(
                          color: color.toARGB32(),
                          opacity: _opacity,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VioColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHSVPicker() {
    return SizedBox(
      height: 180,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onPanStart: (details) =>
                _handleSVChange(details.localPosition, constraints.biggest),
            onPanUpdate: (details) =>
                _handleSVChange(details.localPosition, constraints.biggest),
            child: CustomPaint(
              size: constraints.biggest,
              painter: _SVPickerPainter(
                hue: _hsvColor.hue,
                saturation: _hsvColor.saturation,
                value: _hsvColor.value,
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleSVChange(Offset position, Size size) {
    final saturation = (position.dx / size.width).clamp(0.0, 1.0);
    final value = 1.0 - (position.dy / size.height).clamp(0.0, 1.0);
    _updateFromHSV(_hsvColor.withSaturation(saturation).withValue(value));
  }

  Widget _buildHueSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hue',
          style: VioTypography.labelSmall.copyWith(
            color: VioColors.textSecondary,
          ),
        ),
        const SizedBox(height: VioSpacing.xs),
        SizedBox(
          height: 20,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onPanStart: (details) => _handleHueChange(
                  details.localPosition.dx,
                  constraints.maxWidth,
                ),
                onPanUpdate: (details) => _handleHueChange(
                  details.localPosition.dx,
                  constraints.maxWidth,
                ),
                child: CustomPaint(
                  size: Size(constraints.maxWidth, 20),
                  painter: _HueSliderPainter(hue: _hsvColor.hue),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _handleHueChange(double x, double width) {
    final hue = (x / width * 360).clamp(0.0, 360.0);
    _updateFromHSV(_hsvColor.withHue(hue));
  }

  Widget _buildOpacitySlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Opacity',
              style: VioTypography.labelSmall.copyWith(
                color: VioColors.textSecondary,
              ),
            ),
            Text(
              '${(_opacity * 100).round()}%',
              style: VioTypography.labelSmall.copyWith(
                color: VioColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: VioSpacing.xs),
        SizedBox(
          height: 20,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onPanStart: (details) => _handleOpacityChange(
                  details.localPosition.dx,
                  constraints.maxWidth,
                ),
                onPanUpdate: (details) => _handleOpacityChange(
                  details.localPosition.dx,
                  constraints.maxWidth,
                ),
                child: CustomPaint(
                  size: Size(constraints.maxWidth, 20),
                  painter: _OpacitySliderPainter(
                    color: _hsvColor.toColor(),
                    opacity: _opacity,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _handleOpacityChange(double x, double width) {
    setState(() {
      _opacity = (x / width).clamp(0.0, 1.0);
    });
  }

  Widget _buildColorInputs() {
    return Row(
      children: [
        // Color preview
        SizedBox(
          width: 48,
          height: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
              border: Border.all(color: VioColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(VioSpacing.radiusSm - 1),
              child: Stack(
                children: [
                  // Checkerboard for transparency
                  CustomPaint(
                    size: const Size(48, 48),
                    painter: _CheckerboardPainter(),
                  ),
                  // Color overlay
                  ColoredBox(
                    color: _hsvColor.toColor().withValues(alpha: _opacity),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: VioSpacing.md),
        // Hex input
        Expanded(
          flex: 2,
          child: _buildInputField(
            label: 'HEX',
            controller: _hexController,
            prefix: '#',
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
              LengthLimitingTextInputFormatter(6),
              _UpperCaseTextFormatter(),
            ],
            onSubmitted: _updateFromHex,
          ),
        ),
        const SizedBox(width: VioSpacing.sm),
        // RGB inputs
        Expanded(
          child: _buildInputField(
            label: 'R',
            controller: _rController,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            onSubmitted: (_) => _updateFromRGB(),
          ),
        ),
        const SizedBox(width: VioSpacing.xs),
        Expanded(
          child: _buildInputField(
            label: 'G',
            controller: _gController,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            onSubmitted: (_) => _updateFromRGB(),
          ),
        ),
        const SizedBox(width: VioSpacing.xs),
        Expanded(
          child: _buildInputField(
            label: 'B',
            controller: _bController,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            onSubmitted: (_) => _updateFromRGB(),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    String? prefix,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: VioTypography.labelSmall.copyWith(
            color: VioColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: VioColors.surface,
            borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
            border: Border.all(color: VioColors.border),
          ),
          child: Row(
            children: [
              if (prefix != null)
                Text(
                  prefix,
                  style: VioTypography.bodySmall.copyWith(
                    color: VioColors.textTertiary,
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: VioTypography.bodySmall.copyWith(
                    color: VioColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  inputFormatters: inputFormatters,
                  onSubmitted: onSubmitted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Custom painter for the saturation/value picker area
class _SVPickerPainter extends CustomPainter {
  _SVPickerPainter({
    required this.hue,
    required this.saturation,
    required this.value,
  });

  final double hue;
  final double saturation;
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Draw saturation gradient (white to fully saturated color)
    final satGradient = LinearGradient(
      colors: [Colors.white, HSVColor.fromAHSV(1, hue, 1, 1).toColor()],
    );
    canvas.drawRect(rect, Paint()..shader = satGradient.createShader(rect));

    // Draw value gradient (transparent to black)
    const valGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.black],
    );
    canvas.drawRect(rect, Paint()..shader = valGradient.createShader(rect));

    // Draw selection indicator
    final indicatorX = saturation * size.width;
    final indicatorY = (1 - value) * size.height;
    final indicatorPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white;
    canvas.drawCircle(Offset(indicatorX, indicatorY), 8, indicatorPaint);
    indicatorPaint.color = Colors.black;
    indicatorPaint.strokeWidth = 1;
    canvas.drawCircle(Offset(indicatorX, indicatorY), 9, indicatorPaint);
  }

  @override
  bool shouldRepaint(_SVPickerPainter oldDelegate) =>
      hue != oldDelegate.hue ||
      saturation != oldDelegate.saturation ||
      value != oldDelegate.value;
}

/// Custom painter for the hue slider
class _HueSliderPainter extends CustomPainter {
  _HueSliderPainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));

    // Draw hue gradient
    final colors = List.generate(7, (i) {
      return HSVColor.fromAHSV(1, i * 60.0, 1, 1).toColor();
    });
    final gradient = LinearGradient(colors: colors);
    canvas.drawRRect(rrect, Paint()..shader = gradient.createShader(rect));

    // Draw selection indicator
    final indicatorX = (hue / 360) * size.width;
    final indicatorPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white;
    canvas.drawCircle(Offset(indicatorX, size.height / 2), 8, indicatorPaint);
    indicatorPaint.color = Colors.black;
    indicatorPaint.strokeWidth = 1;
    canvas.drawCircle(Offset(indicatorX, size.height / 2), 9, indicatorPaint);
  }

  @override
  bool shouldRepaint(_HueSliderPainter oldDelegate) => hue != oldDelegate.hue;
}

/// Custom painter for the opacity slider
class _OpacitySliderPainter extends CustomPainter {
  _OpacitySliderPainter({required this.color, required this.opacity});

  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));

    // Draw checkerboard background
    _drawCheckerboard(canvas, size);

    // Draw opacity gradient
    final gradient = LinearGradient(
      colors: [color.withValues(alpha: 0), color],
    );
    canvas.drawRRect(rrect, Paint()..shader = gradient.createShader(rect));

    // Draw selection indicator
    final indicatorX = opacity * size.width;
    final indicatorPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white;
    canvas.drawCircle(Offset(indicatorX, size.height / 2), 8, indicatorPaint);
    indicatorPaint.color = Colors.black;
    indicatorPaint.strokeWidth = 1;
    canvas.drawCircle(Offset(indicatorX, size.height / 2), 9, indicatorPaint);
  }

  void _drawCheckerboard(Canvas canvas, Size size) {
    final paint = Paint();
    const squareSize = 5.0;
    for (var y = 0.0; y < size.height; y += squareSize) {
      for (var x = 0.0; x < size.width; x += squareSize) {
        final isLight = ((x ~/ squareSize) + (y ~/ squareSize)) % 2 == 0;
        paint.color = isLight ? Colors.white : Colors.grey.shade300;
        canvas.drawRect(Rect.fromLTWH(x, y, squareSize, squareSize), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_OpacitySliderPainter oldDelegate) =>
      color != oldDelegate.color || opacity != oldDelegate.opacity;
}

/// Custom painter for the checkerboard pattern (transparency preview)
class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    const squareSize = 6.0;
    for (var y = 0.0; y < size.height; y += squareSize) {
      for (var x = 0.0; x < size.width; x += squareSize) {
        final isLight = ((x ~/ squareSize) + (y ~/ squareSize)) % 2 == 0;
        paint.color = isLight ? Colors.white : Colors.grey.shade300;
        canvas.drawRect(Rect.fromLTWH(x, y, squareSize, squareSize), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Text formatter that converts input to uppercase
class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
