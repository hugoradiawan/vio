//! Rasterizes [`RenderShape`]s into RGBA pixel buffers using `tiny-skia`.
//!
//! This module provides:
//! - [`is_tile_rasterizable`] to determine if a shape can be rendered by tiles
//! - [`rasterize_tile`] to render shapes overlapping a tile into pixel data

use tiny_skia::{
    Color, FillRule, LineCap, LineJoin, LinearGradient, Paint, Path, PathBuilder, Pixmap, Point,
    RadialGradient, Rect, Shader, SpreadMode, Stroke, Transform,
};

use crate::math::aabb::Aabb;
use crate::math::matrix2d::Matrix2D;
use crate::rasterizer::tiles::TILE_SIZE;
use crate::scene_graph::shape::*;
use crate::scene_graph::tree::SceneTree;

/// Check if a shape can be rasterized by the tile system.
///
/// Returns `false` for shapes that need the Dart draw-command pipeline:
/// - Text, Image, SVG, Path, Bool shapes (need font/bitmap/SVG support)
/// - Shapes with visible shadow or blur effects
/// - Container shapes (Groups, Frames — need tree traversal)
/// - Shapes inside clipping frames (tiles don't apply clip masks)
/// - Hidden / zero-opacity shapes
pub fn is_tile_rasterizable(shape: &RenderShape, tree: &SceneTree) -> bool {
    if shape.hidden || shape.opacity <= 0.0 {
        return false;
    }
    // Shapes with shadow/blur effects go through draw commands
    if shape
        .shadow
        .as_ref()
        .map_or(false, |s| !s.hidden)
    {
        return false;
    }
    if shape
        .blur
        .as_ref()
        .map_or(false, |b| !b.hidden)
    {
        return false;
    }
    // Containers need tree traversal (children, clipping, etc.)
    if shape.is_container() {
        return false;
    }
    // Only support Rectangle and Ellipse geometry for now
    if !matches!(
        shape.geometry,
        ShapeGeometry::Rectangle { .. } | ShapeGeometry::Ellipse { .. }
    ) {
        return false;
    }
    // Must have at least one visible fill or stroke
    let has_visible_fill = shape.fills.iter().any(|f| !f.hidden);
    let has_visible_stroke = shape.strokes.iter().any(|s| !s.hidden);
    if !has_visible_fill && !has_visible_stroke {
        return false;
    }
    // Shapes inside clipping frames: tiles can't clip, delegate to draw cmds.
    // Check both parent_id (for nested containers like groups) and frame_id
    // (for direct children of frames).
    let container_id = shape.parent_id.as_deref().or(shape.frame_id.as_deref());
    if let Some(cid) = container_id {
        if let Some(container) = tree.get(cid) {
            if container.clips_content() {
                return false;
            }
        }
    }
    true
}

/// Rasterize shapes into a tile's RGBA pixel buffer.
///
/// `shapes` must be sorted in paint order (back to front by sort_order).
/// Returns premultiplied RGBA pixel data (`TILE_SIZE × TILE_SIZE × 4` bytes).
pub fn rasterize_tile(
    shapes: &[&RenderShape],
    tile_world_bounds: &Aabb,
    zoom: f64,
) -> Vec<u8> {
    let mut pixmap = match Pixmap::new(TILE_SIZE, TILE_SIZE) {
        Some(p) => p,
        None => return vec![0u8; (TILE_SIZE * TILE_SIZE * 4) as usize],
    };

    // Transform: world coords → tile pixel coords
    // pixel = (world - tile_origin) * zoom
    let z = zoom as f32;
    let tile_ts = Transform::from_row(
        z,
        0.0,
        0.0,
        z,
        -tile_world_bounds.min_x as f32 * z,
        -tile_world_bounds.min_y as f32 * z,
    );

    for shape in shapes {
        if shape.hidden || shape.opacity <= 0.0 {
            continue;
        }
        paint_shape(&mut pixmap, shape, &tile_ts);
    }

    pixmap.data().to_vec()
}

// ---------------------------------------------------------------------------
// Shape painting
// ---------------------------------------------------------------------------

/// Paint a single shape onto the pixmap using its world transform.
fn paint_shape(pixmap: &mut Pixmap, shape: &RenderShape, tile_ts: &Transform) {
    let shape_ts = matrix2d_to_transform(&shape.transform);
    let combined = tile_ts.pre_concat(shape_ts);

    let path = match build_shape_path(&shape.geometry) {
        Some(p) => p,
        None => return,
    };

    // --- Fills (back to front) ---
    for fill in &shape.fills {
        if fill.hidden {
            continue;
        }
        let effective_opacity = fill.opacity * shape.opacity;
        let mut paint = Paint::default();
        paint.anti_alias = true;

        if let Some(ref gradient) = fill.gradient {
            if let Some(shader) =
                build_gradient_shader(gradient, &shape.geometry, effective_opacity)
            {
                paint.shader = shader;
            } else {
                set_paint_color(&mut paint, fill.color, effective_opacity);
            }
        } else {
            set_paint_color(&mut paint, fill.color, effective_opacity);
        }

        pixmap.fill_path(&path, &paint, FillRule::Winding, combined, None);
    }

    // --- Strokes (back to front) ---
    for stroke_def in &shape.strokes {
        if stroke_def.hidden {
            continue;
        }
        let effective_opacity = stroke_def.opacity * shape.opacity;
        let mut paint = Paint::default();
        paint.anti_alias = true;
        set_paint_color(&mut paint, stroke_def.color, effective_opacity);

        let stroke = Stroke {
            width: stroke_def.width as f32,
            line_cap: match stroke_def.cap {
                StrokeCap::Butt => LineCap::Butt,
                StrokeCap::Round => LineCap::Round,
                StrokeCap::Square => LineCap::Square,
            },
            line_join: match stroke_def.join {
                StrokeJoin::Miter => LineJoin::Miter,
                StrokeJoin::Round => LineJoin::Round,
                StrokeJoin::Bevel => LineJoin::Bevel,
            },
            miter_limit: 4.0,
            ..Stroke::default()
        };

        pixmap.stroke_path(&path, &paint, &stroke, combined, None);
    }
}

// ---------------------------------------------------------------------------
// Path builders
// ---------------------------------------------------------------------------

/// Build a tiny-skia `Path` from shape geometry.
fn build_shape_path(geometry: &ShapeGeometry) -> Option<Path> {
    match geometry {
        ShapeGeometry::Rectangle {
            width,
            height,
            r1,
            r2,
            r3,
            r4,
        } => {
            let w = *width as f32;
            let h = *height as f32;

            if *r1 == 0.0 && *r2 == 0.0 && *r3 == 0.0 && *r4 == 0.0 {
                // Simple rectangle (no rounding)
                let rect = Rect::from_xywh(0.0, 0.0, w, h)?;
                let mut pb = PathBuilder::new();
                pb.push_rect(rect);
                pb.finish()
            } else {
                // Rounded rectangle with per-corner radii
                build_rounded_rect_path(w, h, *r1 as f32, *r2 as f32, *r3 as f32, *r4 as f32)
            }
        }
        ShapeGeometry::Ellipse { width, height } => {
            let w = *width as f32;
            let h = *height as f32;
            let rect = Rect::from_xywh(0.0, 0.0, w, h)?;
            let mut pb = PathBuilder::new();
            pb.push_oval(rect);
            pb.finish()
        }
        // Frame, Group, Text, Image, SVG, Path, Bool — not handled
        _ => None,
    }
}

/// Build a path for a rectangle with individual corner radii.
///
/// `r1`=top-left, `r2`=top-right, `r3`=bottom-right, `r4`=bottom-left.
/// Uses cubic Bézier approximation for quarter-circle arcs.
fn build_rounded_rect_path(
    w: f32,
    h: f32,
    r1: f32,
    r2: f32,
    r3: f32,
    r4: f32,
) -> Option<Path> {
    // Clamp radii so they don't exceed half the smaller dimension
    let max_r = (w / 2.0).min(h / 2.0);
    let r1 = r1.min(max_r).max(0.0);
    let r2 = r2.min(max_r).max(0.0);
    let r3 = r3.min(max_r).max(0.0);
    let r4 = r4.min(max_r).max(0.0);

    // Kappa: cubic Bézier control point distance for quarter-circle arcs
    const K: f32 = 0.552_284_8;

    let mut pb = PathBuilder::new();

    // Start after top-left corner arc
    pb.move_to(r1, 0.0);

    // Top edge → top-right corner
    pb.line_to(w - r2, 0.0);
    if r2 > 0.0 {
        pb.cubic_to(w - r2 + r2 * K, 0.0, w, r2 - r2 * K, w, r2);
    }

    // Right edge → bottom-right corner
    pb.line_to(w, h - r3);
    if r3 > 0.0 {
        pb.cubic_to(w, h - r3 + r3 * K, w - r3 + r3 * K, h, w - r3, h);
    }

    // Bottom edge → bottom-left corner
    pb.line_to(r4, h);
    if r4 > 0.0 {
        pb.cubic_to(r4 - r4 * K, h, 0.0, h - r4 + r4 * K, 0.0, h - r4);
    }

    // Left edge → top-left corner
    pb.line_to(0.0, r1);
    if r1 > 0.0 {
        pb.cubic_to(0.0, r1 - r1 * K, r1 - r1 * K, 0.0, r1, 0.0);
    }

    pb.close();
    pb.finish()
}

// ---------------------------------------------------------------------------
// Color / gradient helpers
// ---------------------------------------------------------------------------

/// Convert our u32 color (0xAARRGGBB) to a tiny-skia `Color`, applying opacity.
fn argb_to_color(argb: u32, opacity: f64) -> Color {
    let a = ((argb >> 24) & 0xFF) as f32 / 255.0;
    let r = ((argb >> 16) & 0xFF) as f32 / 255.0;
    let g = ((argb >> 8) & 0xFF) as f32 / 255.0;
    let b = (argb & 0xFF) as f32 / 255.0;
    Color::from_rgba(r, g, b, (a * opacity as f32).clamp(0.0, 1.0))
        .unwrap_or(Color::TRANSPARENT)
}

/// Set a `Paint`'s color from a u32 ARGB + opacity.
fn set_paint_color(paint: &mut Paint, argb: u32, opacity: f64) {
    let color = argb_to_color(argb, opacity);
    paint.set_color(color);
}

/// Convert a `Matrix2D` to a tiny-skia `Transform`.
fn matrix2d_to_transform(m: &Matrix2D) -> Transform {
    // Matrix2D:      tiny-skia Transform:
    // | a  c  e |    sx  kx  tx
    // | b  d  f |    ky  sy  ty
    // | 0  0  1 |
    //
    // Transform::from_row(sx, ky, kx, sy, tx, ty)
    Transform::from_row(
        m.a as f32,
        m.b as f32,
        m.c as f32,
        m.d as f32,
        m.e as f32,
        m.f as f32,
    )
}

/// Build a tiny-skia gradient shader from our gradient definition.
fn build_gradient_shader(
    gradient: &ShapeGradient,
    geometry: &ShapeGeometry,
    opacity: f64,
) -> Option<Shader<'static>> {
    let (w, h) = geometry.dimensions();

    let stops: Vec<tiny_skia::GradientStop> = gradient
        .stops
        .iter()
        .map(|s| {
            let pos_f32 = s.offset.clamp(0.0, 1.0) as f32;
            let color = argb_to_color(s.color, opacity);
            tiny_skia::GradientStop::new(pos_f32, color)
        })
        .collect();

    if stops.len() < 2 {
        return None;
    }

    // Gradient coordinates are relative (0..1) mapped to shape dimensions
    let sx = gradient.start_x as f32 * w as f32;
    let sy = gradient.start_y as f32 * h as f32;
    let ex = gradient.end_x as f32 * w as f32;
    let ey = gradient.end_y as f32 * h as f32;

    match gradient.gradient_type {
        GradientType::Linear => LinearGradient::new(
            Point::from_xy(sx, sy),
            Point::from_xy(ex, ey),
            stops,
            SpreadMode::Pad,
            Transform::identity(),
        ),
        GradientType::Radial => {
            let radius = ((ex - sx).powi(2) + (ey - sy).powi(2)).sqrt().max(0.001);
            RadialGradient::new(
                Point::from_xy(sx, sy),
                Point::from_xy(sx, sy),
                radius,
                stops,
                SpreadMode::Pad,
                Transform::identity(),
            )
        }
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    fn make_rect(
        id: &str,
        x: f64,
        y: f64,
        w: f64,
        h: f64,
        color: u32,
    ) -> RenderShape {
        RenderShape {
            id: id.to_string(),
            shape_type: ShapeType::Rectangle,
            transform: Matrix2D::translation(x, y),
            parent_id: None,
            frame_id: None,
            sort_order: 0,
            opacity: 1.0,
            hidden: false,
            rotation: 0.0,
            fills: vec![ShapeFill {
                color,
                opacity: 1.0,
                hidden: false,
                gradient: None,
            }],
            strokes: vec![],
            shadow: None,
            blur: None,
            geometry: ShapeGeometry::Rectangle {
                width: w,
                height: h,
                r1: 0.0,
                r2: 0.0,
                r3: 0.0,
                r4: 0.0,
            },
        }
    }

    fn make_ellipse(id: &str, x: f64, y: f64, w: f64, h: f64, color: u32) -> RenderShape {
        RenderShape {
            id: id.to_string(),
            shape_type: ShapeType::Ellipse,
            transform: Matrix2D::translation(x, y),
            parent_id: None,
            frame_id: None,
            sort_order: 0,
            opacity: 1.0,
            hidden: false,
            rotation: 0.0,
            fills: vec![ShapeFill {
                color,
                opacity: 1.0,
                hidden: false,
                gradient: None,
            }],
            strokes: vec![],
            shadow: None,
            blur: None,
            geometry: ShapeGeometry::Ellipse {
                width: w,
                height: h,
            },
        }
    }

    #[test]
    fn is_rasterizable_simple_rect() {
        let tree = SceneTree::new();
        let shape = make_rect("r1", 0.0, 0.0, 100.0, 50.0, 0xFF0000FF);
        assert!(is_tile_rasterizable(&shape, &tree));
    }

    #[test]
    fn is_rasterizable_ellipse() {
        let tree = SceneTree::new();
        let shape = make_ellipse("e1", 0.0, 0.0, 100.0, 50.0, 0xFF00FF00);
        assert!(is_tile_rasterizable(&shape, &tree));
    }

    #[test]
    fn not_rasterizable_hidden() {
        let tree = SceneTree::new();
        let mut shape = make_rect("r1", 0.0, 0.0, 100.0, 50.0, 0xFF0000FF);
        shape.hidden = true;
        assert!(!is_tile_rasterizable(&shape, &tree));
    }

    #[test]
    fn not_rasterizable_with_shadow() {
        let tree = SceneTree::new();
        let mut shape = make_rect("r1", 0.0, 0.0, 100.0, 50.0, 0xFF0000FF);
        shape.shadow = Some(ShapeShadow {
            style: ShadowStyle::Drop,
            color: 0xFF000000,
            opacity: 0.5,
            offset_x: 2.0,
            offset_y: 2.0,
            blur: 4.0,
            spread: 0.0,
            hidden: false,
        });
        assert!(!is_tile_rasterizable(&shape, &tree));
    }

    #[test]
    fn not_rasterizable_text() {
        let tree = SceneTree::new();
        let shape = RenderShape {
            id: "t1".to_string(),
            shape_type: ShapeType::Text,
            transform: Matrix2D::identity(),
            parent_id: None,
            frame_id: None,
            sort_order: 0,
            opacity: 1.0,
            hidden: false,
            rotation: 0.0,
            fills: vec![ShapeFill {
                color: 0xFFFFFFFF,
                opacity: 1.0,
                hidden: false,
                gradient: None,
            }],
            strokes: vec![],
            shadow: None,
            blur: None,
            geometry: ShapeGeometry::Text {
                width: 100.0,
                height: 20.0,
                text: "Hello".to_string(),
                font_size: 14.0,
                font_family: "Arial".to_string(),
                font_weight: 400,
                line_height: 1.2,
                letter_spacing_percent: 0.0,
                text_align: TextAlign::Left,
            },
        };
        assert!(!is_tile_rasterizable(&shape, &tree));
    }

    #[test]
    fn not_rasterizable_container() {
        let tree = SceneTree::new();
        let shape = RenderShape {
            id: "g1".to_string(),
            shape_type: ShapeType::Group,
            transform: Matrix2D::identity(),
            parent_id: None,
            frame_id: None,
            sort_order: 0,
            opacity: 1.0,
            hidden: false,
            rotation: 0.0,
            fills: vec![],
            strokes: vec![],
            shadow: None,
            blur: None,
            geometry: ShapeGeometry::Group {
                width: 200.0,
                height: 200.0,
            },
        };
        assert!(!is_tile_rasterizable(&shape, &tree));
    }

    #[test]
    fn not_rasterizable_inside_clipping_frame() {
        let mut tree = SceneTree::new();
        let frame = RenderShape {
            id: "frame1".to_string(),
            shape_type: ShapeType::Frame,
            transform: Matrix2D::identity(),
            parent_id: None,
            frame_id: None,
            sort_order: 0,
            opacity: 1.0,
            hidden: false,
            rotation: 0.0,
            fills: vec![],
            strokes: vec![],
            shadow: None,
            blur: None,
            geometry: ShapeGeometry::Frame {
                width: 200.0,
                height: 200.0,
                clip_content: true,
            },
        };
        tree.insert(frame);

        let mut child = make_rect("child1", 10.0, 10.0, 50.0, 50.0, 0xFF0000FF);
        child.parent_id = Some("frame1".to_string());
        tree.insert(child.clone());

        assert!(!is_tile_rasterizable(&child, &tree));
    }

    #[test]
    fn not_rasterizable_inside_clipping_frame_via_frame_id() {
        let mut tree = SceneTree::new();
        let frame = RenderShape {
            id: "frame1".to_string(),
            shape_type: ShapeType::Frame,
            transform: Matrix2D::identity(),
            parent_id: None,
            frame_id: None,
            sort_order: 0,
            opacity: 1.0,
            hidden: false,
            rotation: 0.0,
            fills: vec![],
            strokes: vec![],
            shadow: None,
            blur: None,
            geometry: ShapeGeometry::Frame {
                width: 200.0,
                height: 200.0,
                clip_content: true,
            },
        };
        tree.insert(frame);

        // Child uses frame_id (not parent_id) — the normal path for
        // shapes that belong to a frame.
        let mut child = make_rect("child1", 10.0, 10.0, 50.0, 50.0, 0xFF0000FF);
        child.frame_id = Some("frame1".to_string());
        tree.insert(child.clone());

        assert!(!is_tile_rasterizable(&child, &tree));
    }

    #[test]
    fn rasterize_tile_produces_correct_size() {
        let shape = make_rect("r1", 10.0, 10.0, 100.0, 50.0, 0xFFFF0000);
        let bounds = Aabb::from_xywh(0.0, 0.0, TILE_SIZE as f64, TILE_SIZE as f64);
        let pixels = rasterize_tile(&[&shape], &bounds, 1.0);
        assert_eq!(pixels.len(), (TILE_SIZE * TILE_SIZE * 4) as usize);
    }

    #[test]
    fn rasterize_tile_red_rect_has_red_pixels() {
        // Red rectangle at (10, 10) size 100×50
        let shape = make_rect("r1", 10.0, 10.0, 100.0, 50.0, 0xFFFF0000);
        let bounds = Aabb::from_xywh(0.0, 0.0, TILE_SIZE as f64, TILE_SIZE as f64);
        let pixels = rasterize_tile(&[&shape], &bounds, 1.0);

        // Check a pixel in the middle of the rect (say, pixel 50, 30)
        let px = 50_usize;
        let py = 30_usize;
        let idx = (py * TILE_SIZE as usize + px) * 4;
        // Should be fully red (premultiplied: R=255, G=0, B=0, A=255)
        assert_eq!(pixels[idx], 255, "R");
        assert_eq!(pixels[idx + 1], 0, "G");
        assert_eq!(pixels[idx + 2], 0, "B");
        assert_eq!(pixels[idx + 3], 255, "A");
    }

    #[test]
    fn rasterize_tile_outside_bounds_is_transparent() {
        // Shape at (10, 10) size 100×50, tile at (0,0)
        let shape = make_rect("r1", 10.0, 10.0, 100.0, 50.0, 0xFFFF0000);
        let bounds = Aabb::from_xywh(0.0, 0.0, TILE_SIZE as f64, TILE_SIZE as f64);
        let pixels = rasterize_tile(&[&shape], &bounds, 1.0);

        // Pixel at (200, 200) should be transparent
        let px = 200_usize;
        let py = 200_usize;
        let idx = (py * TILE_SIZE as usize + px) * 4;
        assert_eq!(pixels[idx + 3], 0, "A should be 0");
    }

    #[test]
    fn rasterize_tile_with_zoom() {
        // Shape at (10, 10) size 100×50 at zoom=2
        // At zoom=2, pixel coords are doubled: shape occupies pixels (20,20)–(220,120)
        let shape = make_rect("r1", 10.0, 10.0, 100.0, 50.0, 0xFFFF0000);
        let bounds = Aabb::from_xywh(0.0, 0.0, TILE_SIZE as f64 / 2.0, TILE_SIZE as f64 / 2.0);
        let pixels = rasterize_tile(&[&shape], &bounds, 2.0);

        // Pixel at (60, 40) should be inside the rect at zoom=2
        let px = 60_usize;
        let py = 40_usize;
        let idx = (py * TILE_SIZE as usize + px) * 4;
        assert_eq!(pixels[idx], 255, "R");
        assert_eq!(pixels[idx + 3], 255, "A");
    }

    #[test]
    fn rasterize_ellipse() {
        let shape = make_ellipse("e1", 10.0, 10.0, 100.0, 100.0, 0xFF00FF00);
        let bounds = Aabb::from_xywh(0.0, 0.0, TILE_SIZE as f64, TILE_SIZE as f64);
        let pixels = rasterize_tile(&[&shape], &bounds, 1.0);

        // Center of ellipse at pixel (60, 60) should be green
        let px = 60_usize;
        let py = 60_usize;
        let idx = (py * TILE_SIZE as usize + px) * 4;
        assert_eq!(pixels[idx], 0, "R");
        assert_eq!(pixels[idx + 1], 255, "G");
        assert_eq!(pixels[idx + 2], 0, "B");
        assert_eq!(pixels[idx + 3], 255, "A");

        // Corner of bounding box (10, 10) should be transparent (outside ellipse)
        let px2 = 10_usize;
        let py2 = 10_usize;
        let idx2 = (py2 * TILE_SIZE as usize + px2) * 4;
        assert_eq!(pixels[idx2 + 3], 0, "Corner should be transparent");
    }

    #[test]
    fn rasterize_rounded_rect() {
        let shape = RenderShape {
            id: "rr1".to_string(),
            shape_type: ShapeType::Rectangle,
            transform: Matrix2D::translation(10.0, 10.0),
            parent_id: None,
            frame_id: None,
            sort_order: 0,
            opacity: 1.0,
            hidden: false,
            rotation: 0.0,
            fills: vec![ShapeFill {
                color: 0xFF0000FF,
                opacity: 1.0,
                hidden: false,
                gradient: None,
            }],
            strokes: vec![],
            shadow: None,
            blur: None,
            geometry: ShapeGeometry::Rectangle {
                width: 100.0,
                height: 100.0,
                r1: 20.0,
                r2: 20.0,
                r3: 20.0,
                r4: 20.0,
            },
        };
        let bounds = Aabb::from_xywh(0.0, 0.0, TILE_SIZE as f64, TILE_SIZE as f64);
        let pixels = rasterize_tile(&[&shape], &bounds, 1.0);

        // Center should be blue
        let px = 60_usize;
        let py = 60_usize;
        let idx = (py * TILE_SIZE as usize + px) * 4;
        assert_eq!(pixels[idx], 0, "R");
        assert_eq!(pixels[idx + 1], 0, "G");
        assert_eq!(pixels[idx + 2], 255, "B");
        assert_eq!(pixels[idx + 3], 255, "A");
    }

    #[test]
    fn rasterize_with_stroke() {
        let shape = RenderShape {
            id: "s1".to_string(),
            shape_type: ShapeType::Rectangle,
            transform: Matrix2D::translation(50.0, 50.0),
            parent_id: None,
            frame_id: None,
            sort_order: 0,
            opacity: 1.0,
            hidden: false,
            rotation: 0.0,
            fills: vec![],
            strokes: vec![ShapeStroke {
                color: 0xFFFF0000,
                width: 4.0,
                opacity: 1.0,
                hidden: false,
                alignment: StrokeAlignment::Center,
                cap: StrokeCap::Butt,
                join: StrokeJoin::Miter,
            }],
            shadow: None,
            blur: None,
            geometry: ShapeGeometry::Rectangle {
                width: 100.0,
                height: 80.0,
                r1: 0.0,
                r2: 0.0,
                r3: 0.0,
                r4: 0.0,
            },
        };
        let bounds = Aabb::from_xywh(0.0, 0.0, TILE_SIZE as f64, TILE_SIZE as f64);
        let pixels = rasterize_tile(&[&shape], &bounds, 1.0);

        // Top edge of the stroke: pixel at (100, 50) should be red
        let px = 100_usize;
        let py = 50_usize;
        let idx = (py * TILE_SIZE as usize + px) * 4;
        assert_eq!(pixels[idx], 255, "R on stroke");
        assert_eq!(pixels[idx + 3], 255, "A on stroke");
    }

    #[test]
    fn build_rounded_rect_path_works() {
        let path = build_rounded_rect_path(100.0, 80.0, 10.0, 15.0, 20.0, 5.0);
        assert!(path.is_some(), "rounded rect path should build");
    }

    #[test]
    fn argb_to_color_opaque_red() {
        let c = argb_to_color(0xFFFF0000, 1.0);
        assert!((c.red() - 1.0).abs() < 0.01);
        assert!(c.green() < 0.01);
        assert!(c.blue() < 0.01);
        assert!((c.alpha() - 1.0).abs() < 0.01);
    }

    #[test]
    fn argb_to_color_with_opacity() {
        let c = argb_to_color(0xFFFF0000, 0.5);
        assert!((c.red() - 1.0).abs() < 0.01);
        assert!((c.alpha() - 0.5).abs() < 0.01);
    }
}
