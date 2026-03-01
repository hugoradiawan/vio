use std::collections::{HashMap, HashSet};

use crate::math::aabb::Aabb;

/// Size of each tile in pixels (width and height).
pub const TILE_SIZE: u32 = 512;

/// Identifies a tile in the grid by column and row.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct TileKey {
    pub col: i32,
    pub row: i32,
}

/// Cached pixel data for a single tile.
pub struct CachedTile {
    /// RGBA pixel data (`TILE_SIZE × TILE_SIZE × 4` bytes, premultiplied alpha).
    pub pixels: Vec<u8>,
    /// Whether this tile needs re-rasterization.
    pub dirty: bool,
}

/// Manages a grid of tiles that cache pre-rendered shape content.
///
/// Tiles are in *world-space* coordinates at a given zoom level.
/// Each tile covers `TILE_SIZE / zoom` world units in each dimension.
/// When zoom changes, all tiles are invalidated and re-rasterized.
pub struct TileGrid {
    /// The zoom level at which tiles were rasterized.
    zoom: f64,
    /// Cached tile pixel data keyed by grid position.
    tiles: HashMap<TileKey, CachedTile>,
    /// Maps each tile to the shape IDs overlapping it.
    tile_shapes: HashMap<TileKey, Vec<String>>,
    /// Maps each shape ID to the set of tiles it overlaps.
    shape_tiles: HashMap<String, HashSet<TileKey>>,
}

impl TileGrid {
    pub fn new() -> Self {
        Self {
            zoom: 1.0,
            tiles: HashMap::new(),
            tile_shapes: HashMap::new(),
            shape_tiles: HashMap::new(),
        }
    }

    /// World-space size of each tile at the current zoom level.
    pub fn tile_world_size(&self) -> f64 {
        TILE_SIZE as f64 / self.zoom
    }

    /// Get the current zoom level.
    pub fn zoom(&self) -> f64 {
        self.zoom
    }

    /// Set the zoom level. If it differs from the current one,
    /// all cached tiles are invalidated (but the shape → tile mapping
    /// is rebuilt lazily via `rebuild_mapping`).
    pub fn set_zoom(&mut self, zoom: f64) {
        let z = if zoom <= 0.0 { 1.0 } else { zoom };
        if (z - self.zoom).abs() > 1e-6 {
            self.zoom = z;
            self.clear();
        }
    }

    /// Clear all cached tiles and mappings.
    pub fn clear(&mut self) {
        self.tiles.clear();
        self.tile_shapes.clear();
        self.shape_tiles.clear();
    }

    /// The world-space AABB of a tile.
    pub fn tile_world_bounds(&self, key: TileKey) -> Aabb {
        let s = self.tile_world_size();
        Aabb::from_xywh(key.col as f64 * s, key.row as f64 * s, s, s)
    }

    /// Determine which tile keys are covered by a world-space AABB.
    pub fn keys_for_aabb(&self, aabb: &Aabb) -> Vec<TileKey> {
        if aabb.is_empty() {
            return vec![];
        }
        let s = self.tile_world_size();
        if s <= 0.0 {
            return vec![];
        }
        let col_min = (aabb.min_x / s).floor() as i32;
        let col_max = ((aabb.max_x / s).ceil() as i32 - 1).max(col_min);
        let row_min = (aabb.min_y / s).floor() as i32;
        let row_max = ((aabb.max_y / s).ceil() as i32 - 1).max(row_min);

        let mut keys = Vec::with_capacity(
            ((col_max - col_min + 1) * (row_max - row_min + 1)) as usize,
        );
        for row in row_min..=row_max {
            for col in col_min..=col_max {
                keys.push(TileKey { col, row });
            }
        }
        keys
    }

    /// Register a shape in the tile grid, recording which tiles it overlaps.
    pub fn register_shape(&mut self, id: &str, world_aabb: &Aabb) {
        // Remove old mapping first
        self.unregister_shape(id);

        let keys = self.keys_for_aabb(world_aabb);
        let key_set: HashSet<TileKey> = keys.iter().copied().collect();

        for &key in &keys {
            self.tile_shapes
                .entry(key)
                .or_default()
                .push(id.to_string());
            // Mark existing cached tile dirty
            if let Some(tile) = self.tiles.get_mut(&key) {
                tile.dirty = true;
            }
        }
        self.shape_tiles.insert(id.to_string(), key_set);
    }

    /// Remove a shape from the tile grid.
    pub fn unregister_shape(&mut self, id: &str) {
        if let Some(old_keys) = self.shape_tiles.remove(id) {
            for key in &old_keys {
                if let Some(shapes) = self.tile_shapes.get_mut(key) {
                    shapes.retain(|s| s != id);
                    if shapes.is_empty() {
                        self.tile_shapes.remove(key);
                    }
                }
                // Mark tile dirty
                if let Some(tile) = self.tiles.get_mut(key) {
                    tile.dirty = true;
                }
            }
        }
    }

    /// Mark all tiles overlapping a given shape as dirty.
    pub fn mark_shape_dirty(&mut self, id: &str) {
        if let Some(keys) = self.shape_tiles.get(id) {
            for key in keys {
                if let Some(tile) = self.tiles.get_mut(key) {
                    tile.dirty = true;
                }
            }
        }
    }

    /// Mark all cached tiles dirty.
    pub fn mark_all_dirty(&mut self) {
        for tile in self.tiles.values_mut() {
            tile.dirty = true;
        }
    }

    /// Get dirty tile keys within the viewport.
    ///
    /// A tile is considered dirty if it is either:
    /// - cached but marked dirty, or
    /// - not cached yet but has shapes overlapping it.
    pub fn dirty_tiles_in_viewport(&self, viewport: &Aabb) -> Vec<TileKey> {
        let visible_keys = self.keys_for_aabb(viewport);
        visible_keys
            .into_iter()
            .filter(|key| match self.tiles.get(key) {
                Some(tile) => tile.dirty,
                None => self.tile_shapes.contains_key(key),
            })
            .collect()
    }

    /// Get all tile keys within the viewport that have content.
    pub fn visible_tiles(&self, viewport: &Aabb) -> Vec<TileKey> {
        let visible_keys = self.keys_for_aabb(viewport);
        visible_keys
            .into_iter()
            .filter(|key| self.tiles.contains_key(key) || self.tile_shapes.contains_key(key))
            .collect()
    }

    /// Get shape IDs for a tile.
    pub fn shapes_for_tile(&self, key: &TileKey) -> &[String] {
        self.tile_shapes
            .get(key)
            .map(|v| v.as_slice())
            .unwrap_or(&[])
    }

    /// Store rasterized pixel data for a tile, marking it clean.
    pub fn store_tile(&mut self, key: TileKey, pixels: Vec<u8>) {
        self.tiles.insert(
            key,
            CachedTile {
                pixels,
                dirty: false,
            },
        );
    }

    /// Get the cached pixels for a tile (only if not dirty).
    pub fn get_tile_pixels(&self, key: &TileKey) -> Option<&[u8]> {
        self.tiles
            .get(key)
            .and_then(|t| if t.dirty { None } else { Some(t.pixels.as_slice()) })
    }

    /// Get cached pixels regardless of dirty flag (for compositor use).
    pub fn get_tile_pixels_any(&self, key: &TileKey) -> Option<&[u8]> {
        self.tiles.get(key).map(|t| t.pixels.as_slice())
    }

    /// Number of cached tiles.
    pub fn cached_tile_count(&self) -> usize {
        self.tiles.len()
    }

    /// Number of dirty tiles among cached ones.
    pub fn dirty_tile_count(&self) -> usize {
        self.tiles.values().filter(|t| t.dirty).count()
    }

    /// Total number of tiles that have shapes registered.
    pub fn occupied_tile_count(&self) -> usize {
        self.tile_shapes.len()
    }

    /// Evict cached tiles that are far outside the viewport to free memory.
    pub fn evict_distant_tiles(&mut self, viewport: &Aabb, margin: f64) {
        let expanded = viewport.inflate(margin);
        let keys_to_remove: Vec<TileKey> = self
            .tiles
            .keys()
            .filter(|key| {
                let bounds = self.tile_world_bounds(**key);
                !expanded.overlaps(&bounds)
            })
            .copied()
            .collect();
        for key in keys_to_remove {
            self.tiles.remove(&key);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn new_grid_is_empty() {
        let grid = TileGrid::new();
        assert_eq!(grid.cached_tile_count(), 0);
        assert_eq!(grid.occupied_tile_count(), 0);
        assert_eq!(grid.zoom(), 1.0);
    }

    #[test]
    fn tile_world_size_at_zoom_1() {
        let grid = TileGrid::new();
        assert_eq!(grid.tile_world_size(), TILE_SIZE as f64);
    }

    #[test]
    fn tile_world_size_at_zoom_2() {
        let mut grid = TileGrid::new();
        grid.set_zoom(2.0);
        assert_eq!(grid.tile_world_size(), TILE_SIZE as f64 / 2.0);
    }

    #[test]
    fn keys_for_small_aabb() {
        let grid = TileGrid::new();
        // A 100×100 shape at origin fits in one 512-world-unit tile
        let aabb = Aabb::from_xywh(10.0, 10.0, 100.0, 100.0);
        let keys = grid.keys_for_aabb(&aabb);
        assert_eq!(keys.len(), 1);
        assert_eq!(keys[0], TileKey { col: 0, row: 0 });
    }

    #[test]
    fn keys_for_aabb_crossing_tiles() {
        let grid = TileGrid::new();
        // A shape spanning from (500, 500) to (600, 600) crosses 4 tiles at zoom=1
        let aabb = Aabb::from_xywh(500.0, 500.0, 100.0, 100.0);
        let keys = grid.keys_for_aabb(&aabb);
        assert_eq!(keys.len(), 4); // (0,0), (1,0), (0,1), (1,1)
    }

    #[test]
    fn keys_for_negative_coords() {
        let grid = TileGrid::new();
        let aabb = Aabb::from_xywh(-100.0, -100.0, 50.0, 50.0);
        let keys = grid.keys_for_aabb(&aabb);
        assert_eq!(keys.len(), 1);
        assert_eq!(keys[0], TileKey { col: -1, row: -1 });
    }

    #[test]
    fn register_and_unregister_shape() {
        let mut grid = TileGrid::new();
        let aabb = Aabb::from_xywh(10.0, 10.0, 100.0, 100.0);
        grid.register_shape("s1", &aabb);
        assert_eq!(grid.occupied_tile_count(), 1);
        assert_eq!(grid.shapes_for_tile(&TileKey { col: 0, row: 0 }).len(), 1);

        grid.unregister_shape("s1");
        assert_eq!(grid.occupied_tile_count(), 0);
    }

    #[test]
    fn dirty_tracking() {
        let mut grid = TileGrid::new();
        let aabb = Aabb::from_xywh(10.0, 10.0, 100.0, 100.0);
        grid.register_shape("s1", &aabb);

        // Store a clean tile
        let key = TileKey { col: 0, row: 0 };
        grid.store_tile(key, vec![0u8; (TILE_SIZE * TILE_SIZE * 4) as usize]);
        assert_eq!(grid.dirty_tile_count(), 0);

        // Mark shape dirty → tile becomes dirty
        grid.mark_shape_dirty("s1");
        assert_eq!(grid.dirty_tile_count(), 1);
    }

    #[test]
    fn dirty_tiles_in_viewport() {
        let mut grid = TileGrid::new();
        let aabb1 = Aabb::from_xywh(10.0, 10.0, 100.0, 100.0);
        let aabb2 = Aabb::from_xywh(2000.0, 2000.0, 100.0, 100.0);
        grid.register_shape("s1", &aabb1);
        grid.register_shape("s2", &aabb2);

        // Viewport only covers the first shape's area
        let viewport = Aabb::from_xywh(0.0, 0.0, 600.0, 600.0);
        let dirty = grid.dirty_tiles_in_viewport(&viewport);
        // s1's tile should be dirty (no cache yet), s2's tile is outside viewport
        assert!(dirty.contains(&TileKey { col: 0, row: 0 }));
        assert!(!dirty.iter().any(|k| k.col == 3 && k.row == 3));
    }

    #[test]
    fn zoom_change_clears_tiles() {
        let mut grid = TileGrid::new();
        let aabb = Aabb::from_xywh(10.0, 10.0, 100.0, 100.0);
        grid.register_shape("s1", &aabb);
        grid.store_tile(TileKey { col: 0, row: 0 }, vec![0u8; 4]);

        assert_eq!(grid.cached_tile_count(), 1);
        grid.set_zoom(2.0);
        assert_eq!(grid.cached_tile_count(), 0);
        assert_eq!(grid.occupied_tile_count(), 0);
    }

    #[test]
    fn evict_distant_tiles() {
        let mut grid = TileGrid::new();
        let key_near = TileKey { col: 0, row: 0 };
        let key_far = TileKey { col: 100, row: 100 };
        grid.store_tile(key_near, vec![0u8; 4]);
        grid.store_tile(key_far, vec![0u8; 4]);

        let viewport = Aabb::from_xywh(0.0, 0.0, 512.0, 512.0);
        grid.evict_distant_tiles(&viewport, 1024.0);

        assert!(grid.get_tile_pixels_any(&key_near).is_some());
        assert!(grid.get_tile_pixels_any(&key_far).is_none());
    }

    #[test]
    fn mark_all_dirty() {
        let mut grid = TileGrid::new();
        grid.store_tile(TileKey { col: 0, row: 0 }, vec![0u8; 4]);
        grid.store_tile(TileKey { col: 1, row: 0 }, vec![0u8; 4]);
        assert_eq!(grid.dirty_tile_count(), 0);

        grid.mark_all_dirty();
        assert_eq!(grid.dirty_tile_count(), 2);
    }

    #[test]
    fn tile_world_bounds() {
        let grid = TileGrid::new();
        let bounds = grid.tile_world_bounds(TileKey { col: 1, row: 2 });
        assert_eq!(bounds.min_x, 512.0);
        assert_eq!(bounds.min_y, 1024.0);
        assert_eq!(bounds.width(), 512.0);
        assert_eq!(bounds.height(), 512.0);
    }

    #[test]
    fn update_shape_moves_tiles() {
        let mut grid = TileGrid::new();
        let aabb1 = Aabb::from_xywh(10.0, 10.0, 100.0, 100.0);
        grid.register_shape("s1", &aabb1);
        assert_eq!(grid.shapes_for_tile(&TileKey { col: 0, row: 0 }).len(), 1);

        // Move shape to a different tile
        let aabb2 = Aabb::from_xywh(600.0, 600.0, 100.0, 100.0);
        grid.register_shape("s1", &aabb2);
        assert_eq!(grid.shapes_for_tile(&TileKey { col: 0, row: 0 }).len(), 0);
        assert_eq!(grid.shapes_for_tile(&TileKey { col: 1, row: 1 }).len(), 1);
    }
}
