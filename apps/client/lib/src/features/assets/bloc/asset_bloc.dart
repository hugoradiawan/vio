import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:vio_core/vio_core.dart';

import '../../../core/grpc/proto_converter.dart';
import '../../../core/services/image_cache_service.dart';
import '../../../gen/vio/v1/asset.pb.dart' as pb_asset;
import '../../../gen/vio/v1/asset.pbgrpc.dart' hide ProjectColor;
import '../../canvas/bloc/canvas_bloc.dart';

part 'asset_event.dart';
part 'asset_state.dart';

/// BLoC managing project assets (graphics and colors).
///
/// Communicates with the backend AssetService via gRPC to perform
/// CRUD operations on graphic assets and palette colors.
class AssetBloc extends Bloc<AssetEvent, AssetState> {
  AssetBloc({
    required AssetServiceClient assetService,
    CanvasBloc? canvasBloc,
  })  : _assetService = assetService,
        _canvasBloc = canvasBloc,
        super(const AssetState()) {
    on<AssetsLoadRequested>(_onAssetsLoadRequested);
    on<AssetUploaded>(_onAssetUploaded);
    on<AssetDeleted>(_onAssetDeleted);
    on<AssetRenamed>(_onAssetRenamed);
    on<AssetMovedToGroup>(_onAssetMovedToGroup);
    on<AssetDataRequested>(_onAssetDataRequested);
    on<ColorCreated>(_onColorCreated);
    on<ColorUpdated>(_onColorUpdated);
    on<ColorDeleted>(_onColorDeleted);
    on<AssetSearchChanged>(_onSearchChanged);
    on<AssetViewModeToggled>(_onViewModeToggled);
  }

  final AssetServiceClient _assetService;
  final CanvasBloc? _canvasBloc;

  // ─── Load ────────────────────────────────────────────────────────────

  Future<void> _onAssetsLoadRequested(
    AssetsLoadRequested event,
    Emitter<AssetState> emit,
  ) async {
    emit(
      state.copyWith(
        status: AssetStatus.loading,
        projectId: event.projectId,
      ),
    );

    try {
      // Load assets and colors in parallel
      final results = await Future.wait([
        _assetService.listAssets(
          pb_asset.ListAssetsRequest()..projectId = event.projectId,
        ),
        _assetService.listColors(
          pb_asset.ListColorsRequest()..projectId = event.projectId,
        ),
      ]);

      final assetsResponse = results[0] as pb_asset.ListAssetsResponse;
      final colorsResponse = results[1] as pb_asset.ListColorsResponse;

      final assets =
          assetsResponse.assets.map(ProtoConverter.assetFromProto).toList();
      final colors = colorsResponse.colors
          .map(ProtoConverter.projectColorFromProto)
          .toList();

      emit(
        state.copyWith(
          status: AssetStatus.loaded,
          assets: assets,
          colors: colors,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AssetStatus.error,
          errorMessage: 'Failed to load assets: $e',
        ),
      );
    }
  }

  // ─── Upload ──────────────────────────────────────────────────────────

  Future<void> _onAssetUploaded(
    AssetUploaded event,
    Emitter<AssetState> emit,
  ) async {
    // Pre-generate a temporary asset ID so we can create the shape
    // on canvas immediately without waiting for the upload to finish.
    final tempId = const Uuid().v4();
    final bytes = Uint8List.fromList(event.data);
    final isSvg = event.mimeType == 'image/svg+xml';

    // If the caller wants a shape on canvas, create it instantly
    // before awaiting the network call.
    final canvasBloc = _canvasBloc;
    if (event.createShapeOnCanvas && canvasBloc != null) {
      // Decode/cache bytes under the temp ID so the painter can
      // render the image right away.
      if (!isSvg) {
        await ImageCacheService.instance.decode(tempId, bytes);
      }

      const defaultDim = 200.0;
      final cx = (event.canvasX ?? 100) - defaultDim / 2;
      final cy = (event.canvasY ?? 100) - defaultDim / 2;
      Shape shape;
      if (isSvg) {
        shape = SvgShape(
          id: const Uuid().v4(),
          name: event.name,
          x: cx,
          y: cy,
          svgWidth: defaultDim,
          svgHeight: defaultDim,
        );
      } else {
        shape = ImageShape(
          id: const Uuid().v4(),
          name: event.name,
          x: cx,
          y: cy,
          imageWidth: defaultDim,
          imageHeight: defaultDim,
          assetId: tempId,
          originalWidth: defaultDim,
          originalHeight: defaultDim,
        );
      }
      canvasBloc.add(ShapeAdded(shape));
    }

    try {
      final response = await _assetService.uploadAsset(
        pb_asset.UploadAssetRequest()
          ..projectId = event.projectId
          ..name = event.name
          ..mimeType = event.mimeType
          ..data = event.data
          ..path = event.path,
      );

      final newAsset = ProtoConverter.assetFromProto(response.asset);
      final updatedAssets = [...state.assets, newAsset];

      // Cache the uploaded bytes for panel preview
      final updatedCache = Map<String, Uint8List>.from(state.assetDataCache)
        ..[newAsset.id] = bytes;

      // Also migrate the temp-ID cache entry to the real ID
      if (tempId != newAsset.id) {
        updatedCache.remove(tempId);
        ImageCacheService.instance.migrateKey(tempId, newAsset.id);
      }

      emit(
        state.copyWith(
          assets: updatedAssets,
          assetDataCache: updatedCache,
          clearError: true,
          lastUploadedAsset: newAsset,
        ),
      );

      // Decode under the real asset ID (if not already decoded)
      if (!ImageCacheService.instance.has(newAsset.id)) {
        await ImageCacheService.instance.decode(newAsset.id, bytes);
      }

      // Update the shape on canvas with the real dimensions and asset ID
      if (event.createShapeOnCanvas && canvasBloc != null) {
        final w = (newAsset.width > 0 ? newAsset.width : 200).toDouble();
        final h = (newAsset.height > 0 ? newAsset.height : 200).toDouble();

        // Find and update the shape we created with the temp ID.
        // Re-center the shape around its original center point so
        // the real dimensions don't shift it away from the drop spot.
        for (final entry in canvasBloc.state.shapes.entries) {
          final s = entry.value;
          if (s is ImageShape && s.assetId == tempId) {
            final centerX = s.x + s.imageWidth / 2;
            final centerY = s.y + s.imageHeight / 2;
            canvasBloc.add(
              ShapeUpdated(
                s.copyWith(
                  assetId: newAsset.id,
                  x: centerX - w / 2,
                  y: centerY - h / 2,
                  imageWidth: w,
                  imageHeight: h,
                  originalWidth: w,
                  originalHeight: h,
                ),
              ),
            );
            break;
          }
        }
      }
    } catch (e) {
      emit(
        state.copyWith(
          errorMessage: 'Failed to upload asset: $e',
        ),
      );
    }
  }

  // ─── Delete Asset ────────────────────────────────────────────────────

  Future<void> _onAssetDeleted(
    AssetDeleted event,
    Emitter<AssetState> emit,
  ) async {
    try {
      await _assetService.deleteAsset(
        pb_asset.DeleteAssetRequest()..id = event.assetId,
      );

      final updatedAssets =
          state.assets.where((a) => a.id != event.assetId).toList();
      final updatedCache = Map<String, Uint8List>.from(state.assetDataCache)
        ..remove(event.assetId);

      emit(
        state.copyWith(
          assets: updatedAssets,
          assetDataCache: updatedCache,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to delete asset: $e'));
    }
  }

  // ─── Rename Asset ────────────────────────────────────────────────────

  Future<void> _onAssetRenamed(
    AssetRenamed event,
    Emitter<AssetState> emit,
  ) async {
    try {
      final response = await _assetService.updateAsset(
        pb_asset.UpdateAssetRequest()
          ..id = event.assetId
          ..name = event.newName,
      );

      final updated = ProtoConverter.assetFromProto(response.asset);
      final updatedAssets = state.assets.map((a) {
        return a.id == event.assetId ? updated : a;
      }).toList();

      emit(state.copyWith(assets: updatedAssets, clearError: true));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to rename asset: $e'));
    }
  }

  // ─── Move Asset to Group ─────────────────────────────────────────────

  Future<void> _onAssetMovedToGroup(
    AssetMovedToGroup event,
    Emitter<AssetState> emit,
  ) async {
    try {
      final response = await _assetService.updateAsset(
        pb_asset.UpdateAssetRequest()
          ..id = event.assetId
          ..path = event.newPath,
      );

      final updated = ProtoConverter.assetFromProto(response.asset);
      final updatedAssets = state.assets.map((a) {
        return a.id == event.assetId ? updated : a;
      }).toList();

      emit(state.copyWith(assets: updatedAssets, clearError: true));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to move asset: $e'));
    }
  }

  // ─── Fetch Full Asset Data ───────────────────────────────────────────

  Future<void> _onAssetDataRequested(
    AssetDataRequested event,
    Emitter<AssetState> emit,
  ) async {
    // Skip if already cached
    if (state.assetDataCache.containsKey(event.assetId)) return;

    try {
      final response = await _assetService.getAsset(
        pb_asset.GetAssetRequest()..id = event.assetId,
      );

      if (response.asset.data.isNotEmpty) {
        final bytes = Uint8List.fromList(response.asset.data);
        final updatedCache = Map<String, Uint8List>.from(state.assetDataCache)
          ..[event.assetId] = bytes;

        emit(state.copyWith(assetDataCache: updatedCache));

        // Decode the image into the paint cache so ShapePainter can use it.
        // This fires ImageCacheService.onImageDecoded on completion,
        // which triggers a canvas repaint.
        await ImageCacheService.instance.decode(event.assetId, bytes);
      }
    } catch (e) {
      emit(
        state.copyWith(
          errorMessage: 'Failed to fetch asset data: $e',
        ),
      );
    }
  }

  // ─── Create Color ───────────────────────────────────────────────────

  Future<void> _onColorCreated(
    ColorCreated event,
    Emitter<AssetState> emit,
  ) async {
    try {
      final request = pb_asset.CreateColorRequest()
        ..projectId = event.projectId
        ..name = event.name
        ..opacity = event.opacity
        ..path = event.path;

      if (event.color != null) {
        request.color = event.color!;
      }
      if (event.gradient != null) {
        request.gradient = ProtoConverter.gradientToProto(event.gradient!);
      }

      final response = await _assetService.createColor(request);
      final newColor = ProtoConverter.projectColorFromProto(response.color);
      final updatedColors = [...state.colors, newColor];

      emit(state.copyWith(colors: updatedColors, clearError: true));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to create color: $e'));
    }
  }

  // ─── Update Color ───────────────────────────────────────────────────

  Future<void> _onColorUpdated(
    ColorUpdated event,
    Emitter<AssetState> emit,
  ) async {
    try {
      final request = pb_asset.UpdateColorRequest()..id = event.colorId;

      if (event.name != null) request.name = event.name!;
      if (event.path != null) request.path = event.path!;
      if (event.color != null) request.color = event.color!;
      if (event.opacity != null) request.opacity = event.opacity!;
      if (event.gradient != null) {
        request.gradient = ProtoConverter.gradientToProto(event.gradient!);
      }

      final response = await _assetService.updateColor(request);
      final updated = ProtoConverter.projectColorFromProto(response.color);
      final updatedColors = state.colors.map((c) {
        return c.id == event.colorId ? updated : c;
      }).toList();

      emit(state.copyWith(colors: updatedColors, clearError: true));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to update color: $e'));
    }
  }

  // ─── Delete Color ───────────────────────────────────────────────────

  Future<void> _onColorDeleted(
    ColorDeleted event,
    Emitter<AssetState> emit,
  ) async {
    try {
      await _assetService.deleteColor(
        pb_asset.DeleteColorRequest()..id = event.colorId,
      );

      final updatedColors =
          state.colors.where((c) => c.id != event.colorId).toList();

      emit(state.copyWith(colors: updatedColors, clearError: true));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to delete color: $e'));
    }
  }

  // ─── Search & View Mode ──────────────────────────────────────────────

  void _onSearchChanged(
    AssetSearchChanged event,
    Emitter<AssetState> emit,
  ) {
    emit(state.copyWith(searchQuery: event.query));
  }

  void _onViewModeToggled(
    AssetViewModeToggled event,
    Emitter<AssetState> emit,
  ) {
    final newMode = state.viewMode == AssetViewMode.grid
        ? AssetViewMode.list
        : AssetViewMode.grid;
    emit(state.copyWith(viewMode: newMode));
  }
}
