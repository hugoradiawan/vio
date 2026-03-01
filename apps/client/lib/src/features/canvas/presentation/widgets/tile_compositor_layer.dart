import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:vio_core/vio_core.dart';

import '../../../../core/services/rust_engine_service.dart';
import '../../../../rust/api/engine.dart';
import '../../bloc/canvas_bloc.dart';

/// Tile size in pixels (matches Rust TILE_SIZE constant).
const _tileSize = 512;

/// Stateful widget that manages tile-based off-screen rasterization.
///
/// Composites pre-rendered tile images from the Rust engine beneath the
/// live draw-command layer. Static shapes (rectangles, ellipses without
/// effects) are rendered into 512×512 pixel tiles by tiny-skia. Only dirty
/// tiles are re-rasterized when shapes change.
///
/// This layer is positioned behind the [RustCanvasLayer] draw-command layer.
/// When tiles are active, draw commands skip tile-rasterized shapes.
class TileCompositorLayer extends StatefulWidget {
  const TileCompositorLayer({
    required this.canvasState,
    super.key,
  });

  final CanvasState canvasState;

  @override
  State<TileCompositorLayer> createState() => _TileCompositorLayerState();
}

class _TileCompositorLayerState extends State<TileCompositorLayer> {
  /// Decoded tile images keyed by "(col,row)".
  final Map<String, _TileCacheEntry> _tileImages = {};
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _rasterizeTiles();
  }

  @override
  void didUpdateWidget(TileCompositorLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rasterizeTiles();
  }

  @override
  void dispose() {
    // Dispose all cached images
    for (final entry in _tileImages.values) {
      entry.image?.dispose();
    }
    _tileImages.clear();
    super.dispose();
  }

  /// Viewport-related calculations
  double get _zoom {
    final z = widget.canvasState.viewMatrix.a.abs();
    return z <= 0 ? 1.0 : z;
  }

  Future<void> _rasterizeTiles() async {
    final gen = ++_generation;
    final state = widget.canvasState;
    final vm = state.viewMatrix;
    final size = state.viewportSize;
    final zoom = _zoom;

    // Compute the visible canvas rect (world coordinates)
    final canvasLeft = -vm.e / zoom;
    final canvasTop = -vm.f / zoom;
    final canvasRight = canvasLeft + size.width / zoom;
    final canvasBottom = canvasTop + size.height / zoom;

    // Inflate viewport slightly for tiles at the edge
    final inflate = 200.0 / zoom;

    try {
      final tiles = await RustEngineService.instance.rasterizeDirtyTiles(
        viewportMinX: canvasLeft - inflate,
        viewportMinY: canvasTop - inflate,
        viewportMaxX: canvasRight + inflate,
        viewportMaxY: canvasBottom + inflate,
        zoom: zoom,
      );

      if (gen != _generation || !mounted) return;

      if (tiles.isEmpty) return;

      // Decode tile pixel data into ui.Image
      final futures = <Future<void>>[];
      for (final tile in tiles) {
        futures.add(_decodeTile(tile, gen));
      }
      await Future.wait(futures);

      if (gen != _generation || !mounted) return;
      setState(() {});
    } catch (e, st) {
      VioLogger.error('TileCompositorLayer: rasterization failed', e, st);
    }
  }

  Future<void> _decodeTile(TileResult tile, int gen) async {
    final key = '${tile.col},${tile.row}';
    final completer = Completer<void>();

    ui.decodeImageFromPixels(
      tile.pixels,
      _tileSize,
      _tileSize,
      ui.PixelFormat.rgba8888,
      (ui.Image image) {
        if (gen != _generation || !mounted) {
          image.dispose();
          if (!completer.isCompleted) completer.complete();
          return;
        }
        // Dispose old image for this tile
        _tileImages[key]?.image?.dispose();
        _tileImages[key] = _TileCacheEntry(
          col: tile.col,
          row: tile.row,
          image: image,
        );
        if (!completer.isCompleted) completer.complete();
      },
    );

    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        isComplex: true,
        painter: _TileCompositePainter(
          tileImages: Map.unmodifiable(_tileImages),
          viewMatrix: widget.canvasState.viewMatrix,
          zoom: _zoom,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal types
// ---------------------------------------------------------------------------

class _TileCacheEntry {
  _TileCacheEntry({
    required this.col,
    required this.row,
    required this.image,
  });

  final int col;
  final int row;
  final ui.Image? image;
}

/// CustomPainter that draws cached tile images at their world positions.
class _TileCompositePainter extends CustomPainter {
  _TileCompositePainter({
    required this.tileImages,
    required this.viewMatrix,
    required this.zoom,
  });

  final Map<String, _TileCacheEntry> tileImages;
  final Matrix2D viewMatrix;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    if (tileImages.isEmpty) return;

    // Apply the view transform
    canvas.save();
    canvas.transform(Float64List.fromList([
      viewMatrix.a, viewMatrix.b, 0, 0,
      viewMatrix.c, viewMatrix.d, 0, 0,
      0, 0, 1, 0,
      viewMatrix.e, viewMatrix.f, 0, 1,
    ]),);

    final tileWorldSize = _tileSize / zoom;

    for (final entry in tileImages.values) {
      final image = entry.image;
      if (image == null) continue;

      final worldX = entry.col * tileWorldSize;
      final worldY = entry.row * tileWorldSize;

      // Each tile is _tileSize pixels but covers tileWorldSize world units.
      // Scale from pixel space (512px) to world space (tileWorldSize).
      canvas.save();
      canvas.translate(worldX, worldY);
      final scale = tileWorldSize / _tileSize;
      canvas.scale(scale, scale);
      canvas.drawImage(image, Offset.zero, Paint());
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TileCompositePainter oldDelegate) {
    return tileImages != oldDelegate.tileImages ||
        viewMatrix != oldDelegate.viewMatrix ||
        zoom != oldDelegate.zoom;
  }
}
