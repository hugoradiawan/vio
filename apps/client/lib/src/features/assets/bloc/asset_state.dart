part of 'asset_bloc.dart';

/// View mode for the assets panel
enum AssetViewMode { list, grid }

/// Status of asset operations
enum AssetStatus { initial, loading, loaded, error }

/// State for asset management
class AssetState extends Equatable {
  const AssetState({
    this.assets = const [],
    this.colors = const [],
    this.status = AssetStatus.initial,
    this.searchQuery = '',
    this.viewMode = AssetViewMode.grid,
    this.errorMessage,
    this.projectId,
    this.assetDataCache = const {},
    this.lastUploadedAsset,
  });

  /// All graphic assets in the project
  final List<ProjectAsset> assets;

  /// All palette colors in the project
  final List<ProjectColor> colors;

  /// Current loading status
  final AssetStatus status;

  /// Search filter query
  final String searchQuery;

  /// Display mode (list or grid)
  final AssetViewMode viewMode;

  /// Error message when status is error
  final String? errorMessage;

  /// Current project ID
  final String? projectId;

  /// Cache of full asset binary data, keyed by asset ID.
  /// Used for canvas rendering after fetching via GetAsset.
  final Map<String, Uint8List> assetDataCache;

  /// The most recently uploaded asset (for listeners that need to react).
  final ProjectAsset? lastUploadedAsset;

  /// Assets filtered by search query
  List<ProjectAsset> get filteredAssets {
    if (searchQuery.isEmpty) return assets;
    final query = searchQuery.toLowerCase();
    return assets
        .where(
          (a) =>
              a.name.toLowerCase().contains(query) ||
              a.path.toLowerCase().contains(query),
        )
        .toList();
  }

  /// Colors filtered by search query
  List<ProjectColor> get filteredColors {
    if (searchQuery.isEmpty) return colors;
    final query = searchQuery.toLowerCase();
    return colors
        .where(
          (c) =>
              c.name.toLowerCase().contains(query) ||
              c.path.toLowerCase().contains(query) ||
              (c.color?.toLowerCase().contains(query) ?? false),
        )
        .toList();
  }

  /// Get unique asset group paths for tree rendering
  Set<String> get assetGroups {
    final groups = <String>{};
    for (final asset in filteredAssets) {
      if (asset.path.isNotEmpty) {
        // Add all intermediate paths too
        final parts = asset.path.split('/');
        for (int i = 1; i <= parts.length; i++) {
          groups.add(parts.sublist(0, i).join('/'));
        }
      }
    }
    return groups;
  }

  /// Get unique color group paths for tree rendering
  Set<String> get colorGroups {
    final groups = <String>{};
    for (final color in filteredColors) {
      if (color.path.isNotEmpty) {
        final parts = color.path.split('/');
        for (int i = 1; i <= parts.length; i++) {
          groups.add(parts.sublist(0, i).join('/'));
        }
      }
    }
    return groups;
  }

  AssetState copyWith({
    List<ProjectAsset>? assets,
    List<ProjectColor>? colors,
    AssetStatus? status,
    String? searchQuery,
    AssetViewMode? viewMode,
    String? errorMessage,
    String? projectId,
    Map<String, Uint8List>? assetDataCache,
    ProjectAsset? lastUploadedAsset,
    bool clearError = false,
  }) {
    return AssetState(
      assets: assets ?? this.assets,
      colors: colors ?? this.colors,
      status: status ?? this.status,
      searchQuery: searchQuery ?? this.searchQuery,
      viewMode: viewMode ?? this.viewMode,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      projectId: projectId ?? this.projectId,
      assetDataCache: assetDataCache ?? this.assetDataCache,
      lastUploadedAsset: lastUploadedAsset ?? this.lastUploadedAsset,
    );
  }

  @override
  List<Object?> get props => [
        assets,
        colors,
        status,
        searchQuery,
        viewMode,
        errorMessage,
        projectId,
        assetDataCache,
        lastUploadedAsset,
      ];
}
