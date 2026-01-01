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
  Rect get bounds =>
      Rect.fromLTWH(x, y, frameWidth, frameHeight);

  /// Whether this frame has auto-layout enabled
  bool get hasAutoLayout => flexLayout != null;

  /// Whether this frame has grid layout
  bool get hasGridLayout => gridLayout != null;

  @override
  FrameShape copyWith({
    String? id,
    String? name,
    String? parentId,
    String? frameId,
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
    return FrameShape(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      frameId: frameId ?? this.frameId,
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
}

/// Flex layout direction
enum FlexDirection { horizontal, vertical }

/// Flex cross-axis alignment
enum FlexAlign { start, center, end, stretch, baseline }

/// Flex main-axis distribution
enum FlexJustify { start, center, end, spaceBetween, spaceAround, spaceEvenly }
