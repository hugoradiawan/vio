# Community 149: tile_world_size_at_zoom_1()

**Members:** 7

## Nodes

- **keys_for_aabb_crossing_tiles()** (`apps_client_rust_src_rasterizer_tiles_rs_keys_for_aabb_crossing_tiles`, Function, degree: 3)
- **keys_for_negative_coords()** (`apps_client_rust_src_rasterizer_tiles_rs_keys_for_negative_coords`, Function, degree: 3)
- **keys_for_small_aabb()** (`apps_client_rust_src_rasterizer_tiles_rs_keys_for_small_aabb`, Function, degree: 3)
- **tile_world_bounds()** (`apps_client_rust_src_rasterizer_tiles_rs_tile_world_bounds`, Function, degree: 3)
- **tile_world_size_at_zoom_1()** (`apps_client_rust_src_rasterizer_tiles_rs_tile_world_size_at_zoom_1`, Function, degree: 3)
- **.evict_distant_tiles()** (`apps_client_rust_src_rasterizer_tiles_rs_tilegrid_evict_distant_tiles`, Method, degree: 2)
- **.new()** (`apps_client_rust_src_rasterizer_tiles_rs_tilegrid_new`, Method, degree: 15)

## Relationships

- apps_client_rust_src_rasterizer_tiles_rs_tilegrid_evict_distant_tiles → apps_client_rust_src_rasterizer_tiles_rs_tile_world_bounds (calls)
- apps_client_rust_src_rasterizer_tiles_rs_tile_world_size_at_zoom_1 → apps_client_rust_src_rasterizer_tiles_rs_tilegrid_new (calls)
- apps_client_rust_src_rasterizer_tiles_rs_keys_for_small_aabb → apps_client_rust_src_rasterizer_tiles_rs_tilegrid_new (calls)
- apps_client_rust_src_rasterizer_tiles_rs_keys_for_aabb_crossing_tiles → apps_client_rust_src_rasterizer_tiles_rs_tilegrid_new (calls)
- apps_client_rust_src_rasterizer_tiles_rs_keys_for_negative_coords → apps_client_rust_src_rasterizer_tiles_rs_tilegrid_new (calls)
- apps_client_rust_src_rasterizer_tiles_rs_tile_world_bounds → apps_client_rust_src_rasterizer_tiles_rs_tilegrid_new (calls)

