use criterion::{criterion_group, criterion_main, BenchmarkId, Criterion};
use rust_lib_vio_client::math::matrix2d::Matrix2D;
use rust_lib_vio_client::scene_graph::shape::*;
use rust_lib_vio_client::scene_graph::spatial_index::SpatialIndex;
use rust_lib_vio_client::api::engine::CanvasEngine;

fn make_shapes(count: usize) -> Vec<RenderShape> {
    (0..count)
        .map(|i| {
            let x = (i % 100) as f64 * 30.0;
            let y = (i / 100) as f64 * 30.0;
            RenderShape {
                id: format!("s{i}"),
                shape_type: ShapeType::Rectangle,
                transform: Matrix2D::translation(x, y),
                parent_id: None,
                frame_id: None,
                sort_order: i as i32,
                opacity: 1.0,
                hidden: false,
                rotation: 0.0,
                fills: vec![],
                strokes: vec![],
                shadow: None,
                blur: None,
                geometry: ShapeGeometry::Rectangle {
                    width: 25.0,
                    height: 25.0,
                    r1: 4.0,
                    r2: 4.0,
                    r3: 4.0,
                    r4: 4.0,
                },
            }
        })
        .collect()
}

fn bench_spatial_index_build(c: &mut Criterion) {
    let mut group = c.benchmark_group("spatial_index_build");
    for count in [100, 500, 1000, 5000] {
        let shapes = make_shapes(count);
        group.bench_with_input(
            BenchmarkId::from_parameter(count),
            &shapes,
            |b, shapes| b.iter(|| SpatialIndex::build(shapes)),
        );
    }
    group.finish();
}

fn bench_visibility_query(c: &mut Criterion) {
    let mut group = c.benchmark_group("visibility_query");
    for count in [100, 500, 1000, 5000] {
        let shapes = make_shapes(count);
        let index = SpatialIndex::build(&shapes);
        group.bench_with_input(
            BenchmarkId::from_parameter(count),
            &index,
            |b, index| {
                b.iter(|| index.query_visible(0.0, 0.0, 1920.0, 1080.0));
            },
        );
    }
    group.finish();
}

fn bench_hit_test(c: &mut Criterion) {
    let mut group = c.benchmark_group("hit_test_point");
    for count in [100, 500, 1000, 5000] {
        let shapes = make_shapes(count);
        let mut engine = CanvasEngine::create();
        engine.load_all_shapes(shapes);
        group.bench_with_input(
            BenchmarkId::from_parameter(count),
            &engine,
            |b, engine| {
                b.iter(|| engine.hit_test_point(150.0, 150.0));
            },
        );
    }
    group.finish();
}

criterion_group!(benches, bench_spatial_index_build, bench_visibility_query, bench_hit_test);
criterion_main!(benches);
