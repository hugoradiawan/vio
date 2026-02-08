import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Global cache for decoded images used by the canvas painter.
///
/// Stores decoded [ui.Image] objects keyed by asset ID. Since
/// [CustomPainter.paint] is synchronous, images must be pre-decoded
/// before the painter can use them.
class ImageCacheService {
  ImageCacheService._();

  static final instance = ImageCacheService._();

  final Map<String, ui.Image> _cache = {};
  final Set<String> _pending = {};

  /// Check if an image is already cached and decoded.
  bool has(String assetId) => _cache.containsKey(assetId);

  /// Check if an image is currently being decoded.
  bool isPending(String assetId) => _pending.contains(assetId);

  /// Get a decoded image by asset ID, or null if not cached.
  ui.Image? get(String assetId) => _cache[assetId];

  /// Decode image bytes and store in cache.
  ///
  /// Returns the decoded [ui.Image], or null if decoding fails.
  /// Fires [onImageDecoded] when complete so painters can repaint.
  Future<ui.Image?> decode(String assetId, Uint8List bytes) async {
    if (_cache.containsKey(assetId)) return _cache[assetId];
    if (_pending.contains(assetId)) return null;

    _pending.add(assetId);

    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      _cache[assetId] = image;
      _pending.remove(assetId);

      // Notify listeners that a new image is available
      _imageDecodedController.add(assetId);

      return image;
    } catch (e) {
      _pending.remove(assetId);
      return null;
    }
  }

  /// Stream that fires when a new image has been decoded.
  /// Canvas painters can listen to this to trigger a repaint.
  Stream<String> get onImageDecoded => _imageDecodedController.stream;
  final _imageDecodedController = StreamController<String>.broadcast();

  /// Remove a cached image.
  void evict(String assetId) {
    _cache[assetId]?.dispose();
    _cache.remove(assetId);
  }

  /// Move a cached image from [oldKey] to [newKey].
  /// Used when a temporary asset ID is replaced by the real one after upload.
  void migrateKey(String oldKey, String newKey) {
    final image = _cache.remove(oldKey);
    if (image != null) {
      _cache[newKey] = image;
      _imageDecodedController.add(newKey);
    }
    _pending.remove(oldKey);
  }

  /// Clear the entire cache.
  void clear() {
    for (final image in _cache.values) {
      image.dispose();
    }
    _cache.clear();
    _pending.clear();
  }

  void dispose() {
    clear();
    _imageDecodedController.close();
  }
}
