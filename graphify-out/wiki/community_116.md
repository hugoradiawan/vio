# Community 116: make_shapes()

**Members:** 10

## Nodes

- **scene_bench** (`apps_client_rust_benches_scene_bench_rs`, File, degree: 9)
- **bench_hit_test()** (`apps_client_rust_benches_scene_bench_rs_bench_hit_test`, Function, degree: 2)
- **bench_spatial_index_build()** (`apps_client_rust_benches_scene_bench_rs_bench_spatial_index_build`, Function, degree: 2)
- **bench_visibility_query()** (`apps_client_rust_benches_scene_bench_rs_bench_visibility_query`, Function, degree: 2)
- **criterion::{criterion_group, criterion_main, BenchmarkId, Criterion}** (`apps_client_rust_benches_scene_bench_rs_import_criterion_criterion_group_criterion_main_benchmarkid_criterion`, Module, degree: 1)
- **rust_lib_vio_client::api::engine::CanvasEngine** (`apps_client_rust_benches_scene_bench_rs_import_rust_lib_vio_client_api_engine_canvasengine`, Module, degree: 1)
- **rust_lib_vio_client::math::matrix2d::Matrix2D** (`apps_client_rust_benches_scene_bench_rs_import_rust_lib_vio_client_math_matrix2d_matrix2d`, Module, degree: 1)
- **rust_lib_vio_client::scene_graph::shape::*** (`apps_client_rust_benches_scene_bench_rs_import_rust_lib_vio_client_scene_graph_shape`, Module, degree: 1)
- **rust_lib_vio_client::scene_graph::spatial_index::SpatialIndex** (`apps_client_rust_benches_scene_bench_rs_import_rust_lib_vio_client_scene_graph_spatial_index_spatialindex`, Module, degree: 1)
- **make_shapes()** (`apps_client_rust_benches_scene_bench_rs_make_shapes`, Function, degree: 4)

## Relationships

- apps_client_rust_benches_scene_bench_rs → apps_client_rust_benches_scene_bench_rs_import_criterion_criterion_group_criterion_main_benchmarkid_criterion (imports)
- apps_client_rust_benches_scene_bench_rs → apps_client_rust_benches_scene_bench_rs_import_rust_lib_vio_client_math_matrix2d_matrix2d (imports)
- apps_client_rust_benches_scene_bench_rs → apps_client_rust_benches_scene_bench_rs_import_rust_lib_vio_client_scene_graph_shape (imports)
- apps_client_rust_benches_scene_bench_rs → apps_client_rust_benches_scene_bench_rs_import_rust_lib_vio_client_scene_graph_spatial_index_spatialindex (imports)
- apps_client_rust_benches_scene_bench_rs → apps_client_rust_benches_scene_bench_rs_import_rust_lib_vio_client_api_engine_canvasengine (imports)
- apps_client_rust_benches_scene_bench_rs → apps_client_rust_benches_scene_bench_rs_make_shapes (defines)
- apps_client_rust_benches_scene_bench_rs → apps_client_rust_benches_scene_bench_rs_bench_spatial_index_build (defines)
- apps_client_rust_benches_scene_bench_rs → apps_client_rust_benches_scene_bench_rs_bench_visibility_query (defines)
- apps_client_rust_benches_scene_bench_rs → apps_client_rust_benches_scene_bench_rs_bench_hit_test (defines)
- apps_client_rust_benches_scene_bench_rs_bench_spatial_index_build → apps_client_rust_benches_scene_bench_rs_make_shapes (calls)
- apps_client_rust_benches_scene_bench_rs_bench_visibility_query → apps_client_rust_benches_scene_bench_rs_make_shapes (calls)
- apps_client_rust_benches_scene_bench_rs_bench_hit_test → apps_client_rust_benches_scene_bench_rs_make_shapes (calls)

