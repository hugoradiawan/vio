# Community 112: world_aabb_with_translation()

**Members:** 10

## Nodes

- **is_container_for_frame()** (`apps_client_rust_src_scene_graph_shape_rs_is_container_for_frame`, Function, degree: 4)
- **is_not_container_for_rectangle()** (`apps_client_rust_src_scene_graph_shape_rs_is_not_container_for_rectangle`, Function, degree: 4)
- **local_bounds_of_rectangle()** (`apps_client_rust_src_scene_graph_shape_rs_local_bounds_of_rectangle`, Function, degree: 3)
- **make_rect_shape()** (`apps_client_rust_src_scene_graph_shape_rs_make_rect_shape`, Function, degree: 5)
- **RenderShape** (`apps_client_rust_src_scene_graph_shape_rs_rendershape`, Struct, degree: 5)
- **.clips_content()** (`apps_client_rust_src_scene_graph_shape_rs_rendershape_clips_content`, Method, degree: 3)
- **.is_container()** (`apps_client_rust_src_scene_graph_shape_rs_rendershape_is_container`, Method, degree: 3)
- **.local_bounds()** (`apps_client_rust_src_scene_graph_shape_rs_rendershape_local_bounds`, Method, degree: 4)
- **.world_aabb()** (`apps_client_rust_src_scene_graph_shape_rs_rendershape_world_aabb`, Method, degree: 3)
- **world_aabb_with_translation()** (`apps_client_rust_src_scene_graph_shape_rs_world_aabb_with_translation`, Function, degree: 3)

## Relationships

- apps_client_rust_src_scene_graph_shape_rs_rendershape → apps_client_rust_src_scene_graph_shape_rs_rendershape_local_bounds (defines)
- apps_client_rust_src_scene_graph_shape_rs_rendershape → apps_client_rust_src_scene_graph_shape_rs_rendershape_world_aabb (defines)
- apps_client_rust_src_scene_graph_shape_rs_rendershape → apps_client_rust_src_scene_graph_shape_rs_rendershape_is_container (defines)
- apps_client_rust_src_scene_graph_shape_rs_rendershape → apps_client_rust_src_scene_graph_shape_rs_rendershape_clips_content (defines)
- apps_client_rust_src_scene_graph_shape_rs_rendershape_world_aabb → apps_client_rust_src_scene_graph_shape_rs_rendershape_local_bounds (calls)
- apps_client_rust_src_scene_graph_shape_rs_local_bounds_of_rectangle → apps_client_rust_src_scene_graph_shape_rs_make_rect_shape (calls)
- apps_client_rust_src_scene_graph_shape_rs_local_bounds_of_rectangle → apps_client_rust_src_scene_graph_shape_rs_rendershape_local_bounds (calls)
- apps_client_rust_src_scene_graph_shape_rs_world_aabb_with_translation → apps_client_rust_src_scene_graph_shape_rs_make_rect_shape (calls)
- apps_client_rust_src_scene_graph_shape_rs_world_aabb_with_translation → apps_client_rust_src_scene_graph_shape_rs_rendershape_world_aabb (calls)
- apps_client_rust_src_scene_graph_shape_rs_is_container_for_frame → apps_client_rust_src_scene_graph_shape_rs_make_rect_shape (calls)
- apps_client_rust_src_scene_graph_shape_rs_is_container_for_frame → apps_client_rust_src_scene_graph_shape_rs_rendershape_is_container (calls)
- apps_client_rust_src_scene_graph_shape_rs_is_container_for_frame → apps_client_rust_src_scene_graph_shape_rs_rendershape_clips_content (calls)
- apps_client_rust_src_scene_graph_shape_rs_is_not_container_for_rectangle → apps_client_rust_src_scene_graph_shape_rs_make_rect_shape (calls)
- apps_client_rust_src_scene_graph_shape_rs_is_not_container_for_rectangle → apps_client_rust_src_scene_graph_shape_rs_rendershape_is_container (calls)
- apps_client_rust_src_scene_graph_shape_rs_is_not_container_for_rectangle → apps_client_rust_src_scene_graph_shape_rs_rendershape_clips_content (calls)

