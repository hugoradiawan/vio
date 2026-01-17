import 'package:flutter/rendering.dart';
import 'package:vio_core/vio_core.dart';

/// Frame shape - container for other shapes (like an artboard)
/// Frames can clip their contents and have independent coordinate systems
class FrameShape extends Shape {
  const FrameShape({
    required super.id,
    required super.name,
    required this.x,
    required this.y,
    required this.frameWidth,
    required this.frameHeight,
    super.parentId,
    super.frameId,
    super.transform,
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
    this.clipContent = true,
    this.showContent = true,
    this.children = const [],
    this.gridLayout,
    this.flexLayout,
  }) : super(type: ShapeType.frame);

  /// X position
  final double x;

  /// Y position
  final double y;

  /// Width
  final double frameWidth;

  /// Height
  final double frameHeight;

  /// Whether to clip content to frame bounds
  final bool clipContent;

  /// Whether to show content in the layers panel
  final bool showContent;

  /// Child shape IDs in z-order (bottom to top)
  final List<String> children;

  /// Grid layout configuration
  final FrameGridLayout? gridLayout;

  /// Flex layout configuration
  final FrameFlexLayout? flexLayout;

  @override
  Rect get bounds => Rect.fromLTWH(x, y, frameWidth, frameHeight);

  /// Whether this frame has auto-layout enabled
  bool get hasAutoLayout => flexLayout != null;

  /// Whether this frame has grid layout
  bool get hasGridLayout => gridLayout != null;

  @override
  FrameShape copyWith({
    String? id,
    String? name,
    Object? parentId = kUnset,
    Object? frameId = kUnset,
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
    double? frameWidth,
    double? frameHeight,
    bool? clipContent,
    bool? showContent,
    List<String>? children,
    FrameGridLayout? gridLayout,
    FrameFlexLayout? flexLayout,
  }) {
    final resolvedParentId =
        identical(parentId, kUnset) ? this.parentId : parentId as String?;
    final resolvedFrameId =
        identical(frameId, kUnset) ? this.frameId : frameId as String?;

    return FrameShape(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: resolvedParentId,
      frameId: resolvedFrameId,
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
      frameWidth: frameWidth ?? this.frameWidth,
      frameHeight: frameHeight ?? this.frameHeight,
      clipContent: clipContent ?? this.clipContent,
      showContent: showContent ?? this.showContent,
      children: children ?? this.children,
      gridLayout: gridLayout ?? this.gridLayout,
      flexLayout: flexLayout ?? this.flexLayout,
    );
  }

  @override
  FrameShape moveBy(double dx, double dy) {
    return copyWith(x: x + dx, y: y + dy);
  }

  @override
  Map<String, dynamic> toJson() => {
        ...baseToJson(),
        'x': x,
        'y': y,
        'frameWidth': frameWidth,
        'frameHeight': frameHeight,
        'clipContent': clipContent,
        'showContent': showContent,
        'children': children,
        if (gridLayout != null) 'gridLayout': gridLayout!.toJson(),
        if (flexLayout != null) 'flexLayout': flexLayout!.toJson(),
      };

  factory FrameShape.fromJson(Map<String, dynamic> json) => FrameShape(
        id: json['id'] as String,
        name: json['name'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        frameWidth: (json['frameWidth'] as num).toDouble(),
        frameHeight: (json['frameHeight'] as num).toDouble(),
        parentId: json['parentId'] as String?,
        frameId: json['frameId'] as String?,
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
        clipContent: json['clipContent'] as bool? ?? true,
        showContent: json['showContent'] as bool? ?? true,
        children: (json['children'] as List?)?.cast<String>() ?? const [],
        gridLayout: json['gridLayout'] != null
            ? FrameGridLayout.fromJson(
                json['gridLayout'] as Map<String, dynamic>)
            : null,
        flexLayout: json['flexLayout'] != null
            ? FrameFlexLayout.fromJson(
                json['flexLayout'] as Map<String, dynamic>)
            : null,
      );

  @override
  List<Object?> get props => [
        ...super.props,
        x,
        y,
        frameWidth,
        frameHeight,
        clipContent,
        showContent,
        children,
        gridLayout,
        flexLayout,
      ];
}

/// Grid layout configuration for frames
class FrameGridLayout {
  const FrameGridLayout({
    required this.columns,
    required this.rows,
    this.columnGap = 0,
    this.rowGap = 0,
  });

  final int columns;
  final int rows;
  final double columnGap;
  final double rowGap;

  Map<String, dynamic> toJson() => {
        'columns': columns,
        'rows': rows,
        'columnGap': columnGap,
        'rowGap': rowGap,
      };

  factory FrameGridLayout.fromJson(Map<String, dynamic> json) =>
      FrameGridLayout(
        columns: json['columns'] as int,
        rows: json['rows'] as int,
        columnGap: (json['columnGap'] as num?)?.toDouble() ?? 0,
        rowGap: (json['rowGap'] as num?)?.toDouble() ?? 0,
      );
}

/// Flex layout configuration for auto-layout frames
class FrameFlexLayout {
  const FrameFlexLayout({
    this.direction = FlexDirection.horizontal,
    this.alignItems = FlexAlign.start,
    this.justifyContent = FlexJustify.start,
    this.gap = 0,
    this.paddingTop = 0,
    this.paddingRight = 0,
    this.paddingBottom = 0,
    this.paddingLeft = 0,
    this.wrap = false,
  });

  /// Layout direction
  final FlexDirection direction;

  /// Cross-axis alignment
  final FlexAlign alignItems;

  /// Main-axis distribution
  final FlexJustify justifyContent;

  /// Gap between items
  final double gap;

  /// Padding
  final double paddingTop;
  final double paddingRight;
  final double paddingBottom;
  final double paddingLeft;

  /// Whether items wrap
  final bool wrap;

  Map<String, dynamic> toJson() => {
        'direction': direction.name,
        'alignItems': alignItems.name,
        'justifyContent': justifyContent.name,
        'gap': gap,
        'paddingTop': paddingTop,
        'paddingRight': paddingRight,
        'paddingBottom': paddingBottom,
        'paddingLeft': paddingLeft,
        'wrap': wrap,
      };

  factory FrameFlexLayout.fromJson(Map<String, dynamic> json) =>
      FrameFlexLayout(
        direction: FlexDirection.values.firstWhere(
          (e) => e.name == json['direction'],
          orElse: () => FlexDirection.horizontal,
        ),
        alignItems: FlexAlign.values.firstWhere(
          (e) => e.name == json['alignItems'],
          orElse: () => FlexAlign.start,
        ),
        justifyContent: FlexJustify.values.firstWhere(
          (e) => e.name == json['justifyContent'],
          orElse: () => FlexJustify.start,
        ),
        gap: (json['gap'] as num?)?.toDouble() ?? 0,
        paddingTop: (json['paddingTop'] as num?)?.toDouble() ?? 0,
        paddingRight: (json['paddingRight'] as num?)?.toDouble() ?? 0,
        paddingBottom: (json['paddingBottom'] as num?)?.toDouble() ?? 0,
        paddingLeft: (json['paddingLeft'] as num?)?.toDouble() ?? 0,
        wrap: json['wrap'] as bool? ?? false,
      );
}

/// Flex layout direction
enum FlexDirection { horizontal, vertical }

/// Flex cross-axis alignment
enum FlexAlign { start, center, end, stretch, baseline }

/// Flex main-axis distribution
enum FlexJustify { start, center, end, spaceBetween, spaceAround, spaceEvenly }
