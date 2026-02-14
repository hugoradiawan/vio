import 'package:vio_core/vio_core.dart';

/// Shape change type for diff visualization
enum ShapeChangeType { added, modified, deleted }

/// Individual shape change in a diff (client-side only, computed locally)
class ShapeChange {
  ShapeChange({
    required this.shapeId,
    required this.shapeName,
    required this.changeType,
    this.beforeShape,
    this.afterShape,
    this.changedProperties = const [],
  });

  final String shapeId;
  final String shapeName;
  final ShapeChangeType changeType;
  final Shape? beforeShape;
  final Shape? afterShape;
  final List<String> changedProperties;
}
