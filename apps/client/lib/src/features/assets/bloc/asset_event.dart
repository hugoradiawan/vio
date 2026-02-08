part of 'asset_bloc.dart';

/// Base class for asset events
sealed class AssetEvent {}

/// Load all assets and colors for a project
class AssetsLoadRequested extends AssetEvent {
  AssetsLoadRequested({required this.projectId});
  final String projectId;
}

/// Upload a new graphic asset
class AssetUploaded extends AssetEvent {
  AssetUploaded({
    required this.projectId,
    required this.name,
    required this.mimeType,
    required this.data,
    this.path = '',
    this.createShapeOnCanvas = false,
    this.canvasX,
    this.canvasY,
  });

  final String projectId;
  final String name;
  final String mimeType;
  final List<int> data;
  final String path;

  /// When true, also creates a shape on the canvas after upload.
  final bool createShapeOnCanvas;

  /// Canvas X coordinate for shape creation.
  final double? canvasX;

  /// Canvas Y coordinate for shape creation.
  final double? canvasY;
}

/// Delete an asset
class AssetDeleted extends AssetEvent {
  AssetDeleted({required this.assetId});
  final String assetId;
}

/// Rename an asset
class AssetRenamed extends AssetEvent {
  AssetRenamed({required this.assetId, required this.newName});
  final String assetId;
  final String newName;
}

/// Move an asset to a different group
class AssetMovedToGroup extends AssetEvent {
  AssetMovedToGroup({required this.assetId, required this.newPath});
  final String assetId;
  final String newPath;
}

/// Fetch the full binary data for an asset (for canvas rendering)
class AssetDataRequested extends AssetEvent {
  AssetDataRequested({required this.assetId});
  final String assetId;
}

/// Create a new color in the palette
class ColorCreated extends AssetEvent {
  ColorCreated({
    required this.projectId,
    required this.name,
    this.color,
    this.opacity = 1.0,
    this.gradient,
    this.path = '',
  });

  final String projectId;
  final String name;
  final String? color;
  final double opacity;
  final ShapeGradient? gradient;
  final String path;
}

/// Update an existing color
class ColorUpdated extends AssetEvent {
  ColorUpdated({
    required this.colorId,
    this.name,
    this.path,
    this.color,
    this.opacity,
    this.gradient,
  });

  final String colorId;
  final String? name;
  final String? path;
  final String? color;
  final double? opacity;
  final ShapeGradient? gradient;
}

/// Delete a color
class ColorDeleted extends AssetEvent {
  ColorDeleted({required this.colorId});
  final String colorId;
}

/// Update the search query filter
class AssetSearchChanged extends AssetEvent {
  AssetSearchChanged({required this.query});
  final String query;
}

/// Toggle between list and grid view mode
class AssetViewModeToggled extends AssetEvent {}
