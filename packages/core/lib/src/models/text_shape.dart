import 'package:flutter/rendering.dart';
import 'package:vio_core/vio_core.dart';

/// Text shape
///
/// Minimal MVP model for Penpot-style canvas text.
/// - `fills` is treated as the text color (first fill)
/// - `strokes` currently ignored for rendering
class TextShape extends Shape {
  const TextShape({
    required super.id,
    required super.name,
    required this.x,
    required this.y,
    required this.textWidth,
    required this.textHeight,
    required this.text,
    this.fontSize = 16.0,
    this.fontFamily,
    this.fontWeight,
    this.lineHeight,
    this.letterSpacingPercent = 0.0,
    this.textAlign = TextAlign.left,
    super.parentId,
    super.frameId,
    super.sortOrder = 0,
    super.transform = Matrix2D.identity,
    super.transformInverse,
    super.selrect,
    super.fills,
    super.strokes,
    super.opacity,
    super.hidden,
    super.blocked,
    super.rotation,
    super.constraints,
    super.shadow,
    super.blur,
  }) : super(type: ShapeType.text);

  /// X position (top-left)
  final double x;

  /// Y position (top-left)
  final double y;

  /// Width of the text bounds (in local coordinates)
  final double textWidth;

  /// Height of the text bounds (in local coordinates)
  final double textHeight;

  /// Text content
  final String text;

  /// Font size in logical pixels
  final double fontSize;

  /// Optional font family
  final String? fontFamily;

  /// Optional font weight (CSS-ish numeric weight: 100..900)
  final int? fontWeight;

  /// Line height multiplier (e.g. 1.2 == 120%).
  ///
  /// If null, treat as "auto" (use font defaults).
  final double? lineHeight;

  /// Letter spacing as a percentage of the font size (e.g. 0 == 0%, 5 == 5%).
  final double letterSpacingPercent;

  /// Text alignment
  final TextAlign textAlign;

  @override
  Rect get bounds => Rect.fromLTWH(x, y, textWidth, textHeight);

  @override
  TextShape copyWith({
    String? id,
    String? name,
    Object? parentId = kUnset,
    Object? frameId = kUnset,
    int? sortOrder,
    Matrix2D? transform,
    Matrix2D? transformInverse,
    Rect? selrect,
    List<ShapeFill>? fills,
    List<ShapeStroke>? strokes,
    double? opacity,
    bool? hidden,
    bool? blocked,
    double? rotation,
    ShapeConstraints? constraints,
    ShapeShadow? shadow,
    ShapeBlur? blur,
    double? x,
    double? y,
    double? textWidth,
    double? textHeight,
    String? text,
    double? fontSize,
    String? fontFamily,
    int? fontWeight,
    double? lineHeight,
    double? letterSpacingPercent,
    TextAlign? textAlign,
  }) {
    final resolvedParentId =
        identical(parentId, kUnset) ? this.parentId : parentId as String?;
    final resolvedFrameId =
        identical(frameId, kUnset) ? this.frameId : frameId as String?;

    return TextShape(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: resolvedParentId,
      frameId: resolvedFrameId,
      sortOrder: sortOrder ?? this.sortOrder,
      transform: transform ?? this.transform,
      transformInverse: transformInverse ?? this.transformInverse,
      selrect: selrect ?? this.selrect,
      fills: fills ?? this.fills,
      strokes: strokes ?? this.strokes,
      opacity: opacity ?? this.opacity,
      hidden: hidden ?? this.hidden,
      blocked: blocked ?? this.blocked,
      rotation: rotation ?? this.rotation,
      constraints: constraints ?? this.constraints,
      shadow: shadow ?? this.shadow,
      blur: blur ?? this.blur,
      x: x ?? this.x,
      y: y ?? this.y,
      textWidth: textWidth ?? this.textWidth,
      textHeight: textHeight ?? this.textHeight,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      fontWeight: fontWeight ?? this.fontWeight,
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacingPercent: letterSpacingPercent ?? this.letterSpacingPercent,
      textAlign: textAlign ?? this.textAlign,
    );
  }

  @override
  TextShape moveBy(double dx, double dy) {
    return copyWith(x: x + dx, y: y + dy);
  }

  @override
  Map<String, dynamic> toJson() => {
        ...baseToJson(),
        'x': x,
        'y': y,
        'textWidth': textWidth,
        'textHeight': textHeight,
        'text': text,
        'fontSize': fontSize,
        if (fontFamily != null) 'fontFamily': fontFamily,
        if (fontWeight != null) 'fontWeight': fontWeight,
        if (lineHeight != null) 'lineHeight': lineHeight,
        'letterSpacingPercent': letterSpacingPercent,
        'textAlign': textAlign.name,
      };

  factory TextShape.fromJson(Map<String, dynamic> json) => TextShape(
        id: json['id'] as String,
        name: json['name'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        textWidth: (json['textWidth'] as num?)?.toDouble() ??
            (json['width'] as num?)?.toDouble() ??
            1.0,
        textHeight: (json['textHeight'] as num?)?.toDouble() ??
            (json['height'] as num?)?.toDouble() ??
            1.0,
        text: json['text'] as String? ?? '',
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
        fontFamily: json['fontFamily'] as String?,
        fontWeight: (json['fontWeight'] as num?)?.toInt(),
        lineHeight: (json['lineHeight'] as num?)?.toDouble(),
        letterSpacingPercent:
            (json['letterSpacingPercent'] as num?)?.toDouble() ?? 0.0,
        textAlign: TextAlign.values.firstWhere(
          (e) => e.name == json['textAlign'],
          orElse: () => TextAlign.left,
        ),
        parentId: json['parentId'] as String?,
        frameId: json['frameId'] as String?,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        transform: json['transform'] != null
            ? Matrix2D.fromJson(json['transform'] as Map<String, dynamic>)
            : Matrix2D.identity,
        transformInverse: json['transformInverse'] != null
            ? Matrix2D.fromJson(
                json['transformInverse'] as Map<String, dynamic>)
            : null,
        fills: (json['fills'] as List?)
                ?.map((f) => ShapeFill.fromJson(f as Map<String, dynamic>))
                .toList() ??
            const [],
        strokes: (json['strokes'] as List?)
                ?.map((s) => ShapeStroke.fromJson(s as Map<String, dynamic>))
                .toList() ??
            const [],
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
        hidden: json['hidden'] as bool? ?? false,
        blocked: json['blocked'] as bool? ?? false,
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
        constraints: json['constraints'] != null
            ? ShapeConstraints.fromJson(
                json['constraints'] as Map<String, dynamic>)
            : null,
        shadow: json['shadow'] != null
            ? ShapeShadow.fromJson(json['shadow'] as Map<String, dynamic>)
            : null,
        blur: json['blur'] != null
            ? ShapeBlur.fromJson(json['blur'] as Map<String, dynamic>)
            : null,
      );

  @override
  List<Object?> get props => [
        ...super.props,
        x,
        y,
        textWidth,
        textHeight,
        text,
        fontSize,
        fontFamily,
        fontWeight,
        lineHeight,
        letterSpacingPercent,
        textAlign,
      ];
}
