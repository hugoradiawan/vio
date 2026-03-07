use std::collections::HashSet;

use crate::math::aabb::Aabb;
use crate::render::commands::{DrawCommand, GradientData, StrokeData};
use crate::scene_graph::shape::*;
use crate::scene_graph::tree::SceneTree;

/// Generates a flat list of [`DrawCommand`]s for all visible shapes in
/// paint-order (depth-first, sorted by `sort_order`).
///
/// This is the hot path — called every frame from Dart's `CustomPainter`.
///
/// When `simplify` is `true` the pipeline skips expensive effects like
/// shadows/blurs during pan/zoom interactions, but keeps fill/stroke visuals
/// (gradients and stroke alignment) consistent.
pub fn generate_draw_commands(
    tree: &SceneTree,
    viewport: &Aabb,
    view_matrix: &[f64; 6],
    simplify: bool,
) -> Vec<DrawCommand> {
    generate_draw_commands_impl(tree, viewport, view_matrix, simplify, None)
}

/// Like [`generate_draw_commands`], but skips shapes whose IDs are in
/// `skip_ids`. Used when those shapes have already been rendered into
/// cached tiles by the rasterizer.
pub fn generate_draw_commands_excluding(
    tree: &SceneTree,
    viewport: &Aabb,
    view_matrix: &[f64; 6],
    simplify: bool,
    skip_ids: &HashSet<String>,
) -> Vec<DrawCommand> {
    generate_draw_commands_impl(tree, viewport, view_matrix, simplify, Some(skip_ids))
}

fn generate_draw_commands_impl(
    tree: &SceneTree,
    viewport: &Aabb,
    _view_matrix: &[f64; 6],
    simplify: bool,
    skip_ids: Option<&HashSet<String>>,
) -> Vec<DrawCommand> {
    let capacity = tree.len() * 6; // rough estimate
    let mut cmds = Vec::with_capacity(capacity);

    // NOTE: The view matrix is NOT baked into the commands. Commands are
    // generated in world (canvas) coordinates so they can be cached and
    // replayed with different view transforms on the Dart side during
    // pan/zoom without regenerating. The view_matrix parameter is still
    // used above for viewport culling only.

    // Walk the tree depth-first starting from roots.
    for root_id in tree.root_ids() {
        emit_shape_tree(tree, root_id, viewport, simplify, &mut cmds, skip_ids);
    }

    cmds
}

// ---------------------------------------------------------------------------
// Recursive tree walker
// ---------------------------------------------------------------------------

fn emit_shape_tree(
    tree: &SceneTree,
    id: &str,
    viewport: &Aabb,
    simplify: bool,
    cmds: &mut Vec<DrawCommand>,
    skip_ids: Option<&HashSet<String>>,
) {
    let shape = match tree.get(id) {
        Some(s) => s,
        None => return,
    };

    // Skip hidden / zero-opacity shapes.
    if shape.hidden || shape.opacity <= 0.0 {
        return;
    }

    // Skip shapes that are tile-rasterized (leaf shapes only).
    if let Some(skip) = skip_ids {
        if skip.contains(&shape.id) && !shape.is_container() {
            return;
        }
    }

    let children = tree.children_of(id);
    let has_children = !children.is_empty();

    // Visibility culling via world AABB.
    let aabb = shape.world_aabb();
    let is_visible = viewport.overlaps(&aabb);

    if !is_visible {
        // For clipped frames the entire subtree is invisible.
        if shape.clips_content() {
            return;
        }
        // For non-clipped containers children might still be visible.
        if has_children {
            for child_id in children {
                emit_shape_tree(tree, child_id, viewport, simplify, cmds, skip_ids);
            }
        }
        return;
    }

    // ----- Emit draw commands for this shape -----
    cmds.push(DrawCommand::BeginShape { id: shape.id.clone() });
    emit_shape_commands(shape, simplify, cmds);

    // ----- Recurse into children -----
    if !has_children {
        cmds.push(DrawCommand::EndShape);
        return;
    }

    if shape.clips_content() {
        let (w, h) = shape.geometry.dimensions();
        // Compute the world-space AABB of the frame by transforming its
        // local rect [0,0,w,h] through the full affine matrix. This
        // correctly handles translation, scale, and rotation (via AABB).
        let (bx, by, bw, bh) = shape.transform.transform_rect(0.0, 0.0, w, h);
        cmds.push(DrawCommand::Save);
        cmds.push(DrawCommand::ClipRect {
            rect: [bx, by, bw, bh],
        });

        for child_id in children {
            emit_shape_tree(tree, child_id, viewport, simplify, cmds, skip_ids);
        }
        cmds.push(DrawCommand::Restore);
    } else {
        for child_id in children {
            emit_shape_tree(tree, child_id, viewport, simplify, cmds, skip_ids);
        }
    }

    cmds.push(DrawCommand::EndShape);
}

// ---------------------------------------------------------------------------
// Per-shape command emission
// ---------------------------------------------------------------------------

fn emit_shape_commands(shape: &RenderShape, simplify: bool, cmds: &mut Vec<DrawCommand>) {
    let (w, h) = shape.geometry.dimensions();
    let rect = [0.0, 0.0, w, h];

    // Push shape transform
    cmds.push(DrawCommand::PushTransform {
        matrix: shape.transform.to_array(),
    });

    // Opacity layer (when not simplifying)
    let needs_opacity_layer = shape.opacity < 1.0 && !simplify;
    if needs_opacity_layer {
        cmds.push(DrawCommand::SaveLayer {
            bounds: rect,
            opacity: shape.opacity,
        });
    }

    match &shape.geometry {
        ShapeGeometry::Text { .. } => emit_text_commands(shape, simplify, cmds),
        ShapeGeometry::Image { .. } => emit_image_commands(shape, simplify, cmds),
        _ => emit_general_commands(shape, simplify, cmds),
    }

    // Close opacity layer
    if needs_opacity_layer {
        cmds.push(DrawCommand::Restore);
    }

    // Pop shape transform
    cmds.push(DrawCommand::PopTransform);
}

// ---------------------------------------------------------------------------
// General shapes (rectangle, ellipse, frame, path, svg, group, bool)
// ---------------------------------------------------------------------------

fn emit_general_commands(shape: &RenderShape, simplify: bool, cmds: &mut Vec<DrawCommand>) {
    let (w, h) = shape.geometry.dimensions();
    let rect = [0.0, 0.0, w, h];

    // 1. Drop shadow (behind everything, skip when simplifying)
    if !simplify {
        if let Some(ref shadow) = shape.shadow {
            if !shadow.hidden && shadow.style == ShadowStyle::Drop {
                emit_drop_shadow(shape, shadow, &rect, cmds);
            }
        }
    }

    // 2. Background blur (skip when simplifying)
    if !simplify {
        if let Some(ref blur) = shape.blur {
            if !blur.hidden && blur.blur_type == BlurType::Background && blur.value > 0.0 {
                emit_background_blur(shape, blur, &rect, cmds);
            }
        }
    }

    // 3. Fills (bottom to top)
    for fill in &shape.fills {
        emit_fill(fill, shape, &rect, simplify, cmds);
    }

    // 4. Inner shadow (after fills, skip when simplifying)
    if !simplify {
        if let Some(ref shadow) = shape.shadow {
            if !shadow.hidden && shadow.style == ShadowStyle::Inner {
                emit_inner_shadow(shape, shadow, &rect, cmds);
            }
        }
    }

    // 5. Strokes (bottom to top)
    for stroke in &shape.strokes {
        emit_stroke(stroke, shape, &rect, simplify, cmds);
    }
}

// ---------------------------------------------------------------------------
// Text shape
// ---------------------------------------------------------------------------

fn emit_text_commands(shape: &RenderShape, simplify: bool, cmds: &mut Vec<DrawCommand>) {
    if let ShapeGeometry::Text {
        width,
        height,
        ref text,
        font_size,
        ref font_family,
        font_weight,
        line_height,
        letter_spacing_percent,
        text_align,
    } = shape.geometry
    {
        if text.is_empty() {
            return;
        }

        // Determine text colour from first visible fill, or white.
        let (color, alpha) = first_visible_fill_color(&shape.fills);
        let effective_alpha = if simplify {
            combined_alpha(alpha, shape.opacity)
        } else {
            alpha
        };
        let final_color = apply_alpha_to_color(color, effective_alpha);

        let letter_spacing = if letter_spacing_percent == 0.0 {
            0.0
        } else {
            font_size * (letter_spacing_percent / 100.0)
        };

        let align_u8 = match text_align {
            TextAlign::Left => 0,
            TextAlign::Center => 1,
            TextAlign::Right => 2,
            TextAlign::Justify => 3,
        };

        cmds.push(DrawCommand::DrawText {
            text: text.clone(),
            rect: [0.0, 0.0, width, height],
            font_size,
            font_family: font_family.clone(),
            font_weight,
            color: final_color,
            line_height,
            letter_spacing,
            text_align: align_u8,
        });
    }
}

// ---------------------------------------------------------------------------
// Image shape
// ---------------------------------------------------------------------------

fn emit_image_commands(shape: &RenderShape, simplify: bool, cmds: &mut Vec<DrawCommand>) {
    if let ShapeGeometry::Image {
        width,
        height,
        ref asset_id,
    } = shape.geometry
    {
        let filter_quality: u8 = if simplify { 1 } else { 2 };

        cmds.push(DrawCommand::DrawImage {
            asset_id: asset_id.clone(),
            dst_rect: [0.0, 0.0, width, height],
            filter_quality,
        });

        // Strokes on top
        let rect = [0.0, 0.0, width, height];
        for stroke in &shape.strokes {
            emit_stroke(stroke, shape, &rect, simplify, cmds);
        }
    }
}

// ---------------------------------------------------------------------------
// Fill emission
// ---------------------------------------------------------------------------

fn emit_fill(
    fill: &ShapeFill,
    shape: &RenderShape,
    rect: &[f64; 4],
    simplify: bool,
    cmds: &mut Vec<DrawCommand>,
) {
    if fill.hidden || fill.opacity <= 0.0 {
        return;
    }

    let shape_opacity = if simplify { shape.opacity } else { 1.0 };

    match &shape.geometry {
        ShapeGeometry::Rectangle {
            r1, r2, r3, r4, ..
        } => {
            let radii = [*r1, *r2, *r3, *r4];
            let has_radii = *r1 > 0.0 || *r2 > 0.0 || *r3 > 0.0 || *r4 > 0.0;
            emit_fill_for_rrect(fill, rect, &radii, has_radii, shape_opacity, cmds);
        }
        ShapeGeometry::Ellipse { .. } => {
            emit_fill_for_oval(fill, rect, shape_opacity, cmds);
        }
        ShapeGeometry::Path {
            ref path_data, ..
        } => {
            // Path gradients are currently unsupported in command stream.
            // Keep behavior stable across simplify modes by using solid fill.
            let color = apply_alpha_to_color(fill.color, combined_alpha(fill.opacity, shape_opacity));
            cmds.push(DrawCommand::DrawPath {
                path_data: path_data.clone(),
                color,
                stroke: None,
            });
        }
        // Frame, Group, Svg, Bool, Text (fallback) — use rect
        _ => {
            let radii = [0.0; 4];
            emit_fill_for_rrect(fill, rect, &radii, false, shape_opacity, cmds);
        }
    }
}

fn emit_fill_for_rrect(
    fill: &ShapeFill,
    rect: &[f64; 4],
    radii: &[f64; 4],
    has_radii: bool,
    shape_opacity: f64,
    cmds: &mut Vec<DrawCommand>,
) {
    if let Some(ref gradient) = fill.gradient {
        let gd = to_gradient_data(gradient, fill.opacity);
        if has_radii {
            cmds.push(DrawCommand::DrawRRectGradient {
                rect: *rect,
                radii: *radii,
                gradient: gd,
            });
        } else {
            // Use RRectGradient with zero radii (Dart handles this fine)
            cmds.push(DrawCommand::DrawRRectGradient {
                rect: *rect,
                radii: *radii,
                gradient: gd,
            });
        }
    } else {
        let color = apply_alpha_to_color(fill.color, combined_alpha(fill.opacity, shape_opacity));
        if has_radii {
            cmds.push(DrawCommand::DrawRRect {
                rect: *rect,
                radii: *radii,
                color,
            });
        } else {
            cmds.push(DrawCommand::DrawRect {
                rect: *rect,
                color,
            });
        }
    }
}

fn emit_fill_for_oval(
    fill: &ShapeFill,
    rect: &[f64; 4],
    shape_opacity: f64,
    cmds: &mut Vec<DrawCommand>,
) {
    if let Some(ref gradient) = fill.gradient {
        let gd = to_gradient_data(gradient, fill.opacity);
        cmds.push(DrawCommand::DrawOvalGradient {
            rect: *rect,
            gradient: gd,
        });
    } else {
        let color = apply_alpha_to_color(fill.color, combined_alpha(fill.opacity, shape_opacity));
        cmds.push(DrawCommand::DrawOval {
            rect: *rect,
            color,
        });
    }
}

// ---------------------------------------------------------------------------
// Stroke emission
// ---------------------------------------------------------------------------

fn emit_stroke(
    stroke: &ShapeStroke,
    shape: &RenderShape,
    rect: &[f64; 4],
    simplify: bool,
    cmds: &mut Vec<DrawCommand>,
) {
    if stroke.hidden || stroke.opacity <= 0.0 || stroke.width <= 0.0 {
        return;
    }

    let shape_opacity = if simplify { shape.opacity } else { 1.0 };
    let color = apply_alpha_to_color(stroke.color, combined_alpha(stroke.opacity, shape_opacity));
    let alignment = stroke_alignment_u8(stroke.alignment);

    match &shape.geometry {
        ShapeGeometry::Rectangle {
            r1, r2, r3, r4, ..
        } => {
            cmds.push(DrawCommand::DrawRRectStroke {
                rect: *rect,
                radii: [*r1, *r2, *r3, *r4],
                color,
                stroke_width: stroke.width,
                stroke_alignment: alignment,
            });
        }
        ShapeGeometry::Ellipse { .. } => {
            cmds.push(DrawCommand::DrawOvalStroke {
                rect: *rect,
                color,
                stroke_width: stroke.width,
            });
        }
        ShapeGeometry::Path {
            ref path_data, ..
        } => {
            cmds.push(DrawCommand::DrawPath {
                path_data: path_data.clone(),
                color: 0, // no fill
                stroke: Some(StrokeData {
                    width: stroke.width,
                    color,
                    cap: stroke_cap_u8(stroke.cap),
                    join: stroke_join_u8(stroke.join),
                }),
            });
        }
        _ => {
            // Frame, Group, Svg, Bool → rect stroke
            cmds.push(DrawCommand::DrawRRectStroke {
                rect: *rect,
                radii: [0.0; 4],
                color,
                stroke_width: stroke.width,
                stroke_alignment: alignment,
            });
        }
    }
}

// ---------------------------------------------------------------------------
// Shadow emission
// ---------------------------------------------------------------------------

fn emit_drop_shadow(
    shape: &RenderShape,
    shadow: &ShapeShadow,
    rect: &[f64; 4],
    cmds: &mut Vec<DrawCommand>,
) {
    let sigma = shadow.blur / 2.0;
    let color = apply_alpha_to_color(shadow.color, shadow.opacity);
    let path_type = match &shape.geometry {
        ShapeGeometry::Rectangle { r1, r2, r3, r4, .. } => {
            if *r1 > 0.0 || *r2 > 0.0 || *r3 > 0.0 || *r4 > 0.0 {
                1 // rrect
            } else {
                0 // rect
            }
        }
        ShapeGeometry::Ellipse { .. } => 2, // oval
        _ => 0,
    };
    let radii = match &shape.geometry {
        ShapeGeometry::Rectangle { r1, r2, r3, r4, .. } => [*r1, *r2, *r3, *r4],
        _ => [0.0; 4],
    };

    cmds.push(DrawCommand::DrawShadow {
        path_type,
        rect: *rect,
        radii,
        color,
        blur_sigma: sigma,
        offset: [shadow.offset_x, shadow.offset_y],
        spread: shadow.spread,
    });
}

fn emit_inner_shadow(
    _shape: &RenderShape,
    shadow: &ShapeShadow,
    rect: &[f64; 4],
    cmds: &mut Vec<DrawCommand>,
) {
    // Inner shadows are complex (src-in compositing). Emit as DrawShadow with
    // path_type 3 (inner) so Dart can handle the compositing sequence.
    let sigma = shadow.blur / 2.0;
    let color = apply_alpha_to_color(shadow.color, shadow.opacity);

    cmds.push(DrawCommand::DrawShadow {
        path_type: 3, // inner shadow marker
        rect: *rect,
        radii: [0.0; 4],
        color,
        blur_sigma: sigma,
        offset: [shadow.offset_x, shadow.offset_y],
        spread: shadow.spread,
    });
}

fn emit_background_blur(
    _shape: &RenderShape,
    blur: &ShapeBlur,
    rect: &[f64; 4],
    cmds: &mut Vec<DrawCommand>,
) {
    cmds.push(DrawCommand::PushBlur {
        sigma_x: blur.value,
        sigma_y: blur.value,
        bounds: *rect,
    });
    cmds.push(DrawCommand::PopBlur);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn combined_alpha(a: f64, b: f64) -> f64 {
    (a * b).clamp(0.0, 1.0)
}

/// Apply an alpha multiplier to a colour's existing alpha channel.
fn apply_alpha_to_color(color: u32, alpha: f64) -> u32 {
    let existing_alpha = ((color >> 24) & 0xFF) as f64;
    let new_alpha = ((existing_alpha * alpha).round() as u32).min(255);
    (new_alpha << 24) | (color & 0x00FF_FFFF)
}

fn first_visible_fill_color(fills: &[ShapeFill]) -> (u32, f64) {
    for fill in fills {
        if !fill.hidden && fill.opacity > 0.0 {
            return (fill.color, fill.opacity);
        }
    }
    (0xFFFF_FFFF, 1.0) // white default
}

fn to_gradient_data(gradient: &ShapeGradient, fill_opacity: f64) -> GradientData {
    let colors: Vec<u32> = gradient
        .stops
        .iter()
        .map(|s| apply_alpha_to_color(s.color, fill_opacity))
        .collect();
    let stops: Vec<f64> = gradient.stops.iter().map(|s| s.offset).collect();
    let gradient_type_u8 = match gradient.gradient_type {
        GradientType::Linear => 0,
        GradientType::Radial => 1,
    };

    GradientData {
        gradient_type: gradient_type_u8,
        colors,
        stops,
        start: [gradient.start_x, gradient.start_y],
        end: [gradient.end_x, gradient.end_y],
    }
}

fn stroke_alignment_u8(alignment: StrokeAlignment) -> u8 {
    match alignment {
        StrokeAlignment::Center => 0,
        StrokeAlignment::Inside => 1,
        StrokeAlignment::Outside => 2,
    }
}

fn stroke_cap_u8(cap: StrokeCap) -> u8 {
    match cap {
        StrokeCap::Butt => 0,
        StrokeCap::Round => 1,
        StrokeCap::Square => 2,
    }
}

fn stroke_join_u8(join: StrokeJoin) -> u8 {
    match join {
        StrokeJoin::Miter => 0,
        StrokeJoin::Round => 1,
        StrokeJoin::Bevel => 2,
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::math::matrix2d::Matrix2D;

    fn make_rect(id: &str, x: f64, y: f64, w: f64, h: f64, sort: i32) -> RenderShape {
        RenderShape {
            id: id.to_string(),
            shape_type: ShapeType::Rectangle,
            transform: Matrix2D::translation(x, y),
            parent_id: None,
            frame_id: None,
            sort_order: sort,
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
                width: w,
                height: h,
                r1: 0.0,
                r2: 0.0,
                r3: 0.0,
                r4: 0.0,
            },
        }
    }

    fn make_rect_with_radii(
        id: &str,
        x: f64,
        y: f64,
        w: f64,
        h: f64,
        r: f64,
    ) -> RenderShape {
        let mut s = make_rect(id, x, y, w, h, 0);
        s.geometry = ShapeGeometry::Rectangle {
            width: w,
            height: h,
            r1: r,
            r2: r,
            r3: r,
            r4: r,
        };
        s
    }

    fn make_ellipse(id: &str, x: f64, y: f64, w: f64, h: f64) -> RenderShape {
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
                color: 0xFFFF0000,
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

    fn make_frame(id: &str, x: f64, y: f64, w: f64, h: f64, clip: bool) -> RenderShape {
        RenderShape {
            id: id.to_string(),
            shape_type: ShapeType::Frame,
            transform: Matrix2D::translation(x, y),
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
                width: w,
                height: h,
                clip_content: clip,
            },
        }
    }

    fn make_text(id: &str, x: f64, y: f64) -> RenderShape {
        RenderShape {
            id: id.to_string(),
            shape_type: ShapeType::Text,
            transform: Matrix2D::translation(x, y),
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
                width: 200.0,
                height: 40.0,
                text: "Hello World".to_string(),
                font_size: 16.0,
                font_family: "Inter".to_string(),
                font_weight: 400,
                line_height: 1.2,
                letter_spacing_percent: 0.0,
                text_align: TextAlign::Left,
            },
        }
    }

    fn make_image(id: &str, x: f64, y: f64, w: f64, h: f64) -> RenderShape {
        RenderShape {
            id: id.to_string(),
            shape_type: ShapeType::Image,
            transform: Matrix2D::translation(x, y),
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
            geometry: ShapeGeometry::Image {
                width: w,
                height: h,
                asset_id: "asset-123".to_string(),
            },
        }
    }

    fn large_viewport() -> Aabb {
        Aabb::from_xywh(-10000.0, -10000.0, 20000.0, 20000.0)
    }

    fn identity_view() -> [f64; 6] {
        [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]
    }

    #[test]
    fn empty_scene_generates_view_transform_only() {
        let tree = SceneTree::new();
        let cmds = generate_draw_commands(&tree, &large_viewport(), &identity_view(), false);
        assert_eq!(cmds.len(), 2); // PushTransform + PopTransform
        assert!(matches!(cmds[0], DrawCommand::PushTransform { .. }));
        assert!(matches!(cmds[1], DrawCommand::PopTransform));
    }

    #[test]
    fn single_rect_generates_transform_and_fill() {
        let tree = SceneTree::from_shapes(vec![make_rect("r1", 10.0, 20.0, 100.0, 50.0, 0)]);
        let cmds = generate_draw_commands(&tree, &large_viewport(), &identity_view(), false);

        // Expect: view push, shape push, fill, shape pop, view pop
        assert!(cmds.len() >= 4);
        assert!(matches!(cmds[1], DrawCommand::PushTransform { .. }));
        assert!(matches!(cmds[2], DrawCommand::DrawRect { .. }));
        assert!(matches!(cmds[3], DrawCommand::PopTransform));
    }

    #[test]
    fn rect_with_radii_emits_draw_rrect() {
        let tree = SceneTree::from_shapes(vec![make_rect_with_radii(
            "r1", 0.0, 0.0, 100.0, 50.0, 8.0,
        )]);
        let cmds = generate_draw_commands(&tree, &large_viewport(), &identity_view(), false);

        let has_rrect = cmds.iter().any(|c| matches!(c, DrawCommand::DrawRRect { .. }));
        assert!(has_rrect, "Expected DrawRRect command for rounded rect");
    }

    #[test]
    fn ellipse_emits_draw_oval() {
        let tree = SceneTree::from_shapes(vec![make_ellipse("e1", 0.0, 0.0, 80.0, 60.0)]);
        let cmds = generate_draw_commands(&tree, &large_viewport(), &identity_view(), false);

        let has_oval = cmds.iter().any(|c| matches!(c, DrawCommand::DrawOval { .. }));
        assert!(has_oval, "Expected DrawOval command for ellipse");
    }

    #[test]
    fn text_emits_draw_text() {
        let tree = SceneTree::from_shapes(vec![make_text("t1", 0.0, 0.0)]);
        let cmds = generate_draw_commands(&tree, &large_viewport(), &identity_view(), false);

        let has_text = cmds.iter().any(|c| matches!(c, DrawCommand::DrawText { .. }));
        assert!(has_text, "Expected DrawText command for text shape");
    }

    #[test]
    fn image_emits_draw_image() {
        let tree = SceneTree::from_shapes(vec![make_image("i1", 0.0, 0.0, 640.0, 480.0)]);
        let cmds = generate_draw_commands(&tree, &large_viewport(), &identity_view(), false);

        let has_image = cmds.iter().any(|c| matches!(c, DrawCommand::DrawImage { .. }));
        assert!(has_image, "Expected DrawImage command for image shape");
    }

    #[test]
    fn hidden_shape_skipped() {
        let mut shape = make_rect("r1", 0.0, 0.0, 100.0, 50.0, 0);
        shape.hidden = true;
        let tree = SceneTree::from_shapes(vec![shape]);
        let cmds = generate_draw_commands(&tree, &large_viewport(), &identity_view(), false);

        // Only view push/pop
        assert_eq!(cmds.len(), 2);
    }

    #[test]
    fn zero_opacity_shape_skipped() {
        let mut shape = make_rect("r1", 0.0, 0.0, 100.0, 50.0, 0);
        shape.opacity = 0.0;
        let tree = SceneTree::from_shapes(vec![shape]);
        let cmds = generate_draw_commands(&tree, &large_viewport(), &identity_view(), false);

        assert_eq!(cmds.len(), 2);
    }

    #[test]
    fn offscreen_shape_culled() {
        // Shape at (5000, 5000), viewport is (0,0)-(100,100)
        let tree = SceneTree::from_shapes(vec![make_rect("r1", 5000.0, 5000.0, 50.0, 50.0, 0)]);
        let viewport = Aabb::from_xywh(0.0, 0.0, 100.0, 100.0);
        let cmds = generate_draw_commands(&tree, &viewport, &identity_view(), false);

        // Only view push/pop — shape is culled
        assert_eq!(cmds.len(), 2);
    }

    #[test]
    fn opacity_generates_save_layer() {
        let mut shape = make_rect("r1", 0.0, 0.0, 100.0, 50.0, 0);
        shape.opacity = 0.5;
        let tree = SceneTree::from_shapes(vec![shape]);
        let cmds = generate_draw_commands(&tree, &large_viewport(), &identity_view(), false);

        let has_save_layer = cmds.iter().any(|c| matches!(c, DrawCommand::SaveLayer { .. }));
        assert!(has_save_layer, "Expected SaveLayer for semi-transparent shape");
    }

    #[test]
    fn simplify_skips_opacity_layer() {
        let mut shape = make_rect("r1", 0.0, 0.0, 100.0, 50.0, 0);
        shape.opacity = 0.5;
        let tree = SceneTree::from_shapes(vec![shape]);
        let cmds = generate_draw_commands(&tree, &large_viewport(), &identity_view(), true);

        let has_save_layer = cmds.iter().any(|c| matches!(c, DrawCommand::SaveLayer { .. }));
        assert!(!has_save_layer, "SaveLayer should be skipped in simplify mode");
    }

    #[test]
    fn gradient_fill_emits_gradient_command() {
        let mut shape = make_rect("r1", 0.0, 0.0, 100.0, 50.0, 0);
        shape.fills = vec![ShapeFill {
            color: 0xFF000000,
            opacity: 1.0,
            hidden: false,
            gradient: Some(ShapeGradient {
                gradient_type: GradientType::Linear,
                stops: vec![
                    GradientStop { offset: 0.0, color: 0xFFFF0000 },
                    GradientStop { offset: 1.0, color: 0xFF0000FF },
                ],
                start_x: 0.0,
                start_y: 0.0,
                end_x: 1.0,
                end_y: 1.0,
            }),
        }];
        let tree = SceneTree::from_shapes(vec![shape]);
        let cmds = generate_draw_commands(&tree, &large_viewport(), &identity_view(), false);

        let has_gradient = cmds.iter().any(|c| matches!(c, DrawCommand::DrawRRectGradient { .. }));
        assert!(has_gradient, "Expected gradient command for gradient fill");
    }

    #[test]
    fn simplify_keeps_gradient_rendering() {
        let mut shape = make_rect("r1", 0.0, 0.0, 100.0, 50.0, 0);
        shape.fills = vec![ShapeFill {
            color: 0xFF000000,
            opacity: 1.0,
            hidden: false,
            gradient: Some(ShapeGradient {
                gradient_type: GradientType::Linear,
                stops: vec![
                    GradientStop { offset: 0.0, color: 0xFFFF0000 },
                    GradientStop { offset: 1.0, color: 0xFF0000FF },
                ],
                start_x: 0.0,
                start_y: 0.0,
                end_x: 1.0,
                end_y: 1.0,
            }),
        }];
        let tree = SceneTree::from_shapes(vec![shape]);
        let cmds = generate_draw_commands(&tree, &large_viewport(), &identity_view(), true);

        let has_gradient = cmds.iter().any(|c| matches!(c, DrawCommand::DrawRRectGradient { .. }));
        assert!(has_gradient, "Gradient should be preserved in simplify mode");
    }

    #[test]
    fn simplify_preserves_stroke_alignment() {
        let mut shape = make_rect("r1", 0.0, 0.0, 100.0, 50.0, 0);
        shape.fills = vec![];
        shape.strokes = vec![ShapeStroke {
            color: 0xFFFFA500,
            width: 4.0,
            opacity: 1.0,
            hidden: false,
            alignment: StrokeAlignment::Outside,
            cap: StrokeCap::Round,
            join: StrokeJoin::Round,
        }];

        let tree = SceneTree::from_shapes(vec![shape]);
        let cmds = generate_draw_commands(&tree, &large_viewport(), &identity_view(), true);

        let stroke = cmds.iter().find_map(|c| match c {
            DrawCommand::DrawRRectStroke {
                stroke_alignment, ..
            } => Some(*stroke_alignment),
            _ => None,
        });

        assert_eq!(stroke, Some(2), "Expected outside alignment (2) in simplify mode");
    }

    #[test]
    fn drop_shadow_emitted() {
        let mut shape = make_rect("r1", 0.0, 0.0, 100.0, 50.0, 0);
        shape.shadow = Some(ShapeShadow {
            style: ShadowStyle::Drop,
            color: 0xFF000000,
            opacity: 0.5,
            offset_x: 5.0,
            offset_y: 5.0,
            blur: 10.0,
            spread: 0.0,
            hidden: false,
        });
        let tree = SceneTree::from_shapes(vec![shape]);
        let cmds = generate_draw_commands(&tree, &large_viewport(), &identity_view(), false);

        let has_shadow = cmds.iter().any(|c| matches!(c, DrawCommand::DrawShadow { .. }));
        assert!(has_shadow, "Expected DrawShadow for drop shadow");
    }

    #[test]
    fn simplify_skips_shadow() {
        let mut shape = make_rect("r1", 0.0, 0.0, 100.0, 50.0, 0);
        shape.shadow = Some(ShapeShadow {
            style: ShadowStyle::Drop,
            color: 0xFF000000,
            opacity: 0.5,
            offset_x: 5.0,
            offset_y: 5.0,
            blur: 10.0,
            spread: 0.0,
            hidden: false,
        });
        let tree = SceneTree::from_shapes(vec![shape]);
        let cmds = generate_draw_commands(&tree, &large_viewport(), &identity_view(), true);

        let has_shadow = cmds.iter().any(|c| matches!(c, DrawCommand::DrawShadow { .. }));
        assert!(!has_shadow, "Shadow should be skipped in simplify mode");
    }

    #[test]
    fn stroke_emitted() {
        let mut shape = make_rect("r1", 0.0, 0.0, 100.0, 50.0, 0);
        shape.strokes = vec![ShapeStroke {
            color: 0xFF333333,
            width: 2.0,
            opacity: 1.0,
            hidden: false,
            alignment: StrokeAlignment::Center,
            cap: StrokeCap::Round,
            join: StrokeJoin::Round,
        }];
        let tree = SceneTree::from_shapes(vec![shape]);
        let cmds = generate_draw_commands(&tree, &large_viewport(), &identity_view(), false);

        let has_stroke = cmds.iter().any(|c| matches!(c, DrawCommand::DrawRRectStroke { .. }));
        assert!(has_stroke, "Expected stroke command");
    }

    #[test]
    fn clipping_frame_emits_clip_and_restore() {
        let frame = make_frame("f1", 0.0, 0.0, 800.0, 600.0, true);
        let mut child = make_rect("c1", 10.0, 10.0, 50.0, 50.0, 0);
        child.frame_id = Some("f1".to_string());

        let tree = SceneTree::from_shapes(vec![frame, child]);
        let cmds = generate_draw_commands(&tree, &large_viewport(), &identity_view(), false);

        let has_clip = cmds.iter().any(|c| matches!(c, DrawCommand::ClipRect { .. }));
        let save_count = cmds.iter().filter(|c| matches!(c, DrawCommand::Save)).count();
        let restore_count = cmds.iter().filter(|c| matches!(c, DrawCommand::Restore)).count();

        assert!(has_clip, "Expected ClipRect for clipping frame");
        assert!(save_count > 0, "Expected Save before clip");
        assert_eq!(save_count, restore_count, "Save/Restore should be balanced");
    }

    #[test]
    fn multiple_shapes_in_sort_order() {
        let tree = SceneTree::from_shapes(vec![
            make_rect("r1", 0.0, 0.0, 100.0, 50.0, 0),
            make_rect("r2", 50.0, 50.0, 100.0, 50.0, 1),
            make_ellipse("e1", 100.0, 100.0, 80.0, 60.0),
        ]);
        let cmds = generate_draw_commands(&tree, &large_viewport(), &identity_view(), false);

        // Should have commands for all 3 shapes
        let rect_count = cmds.iter().filter(|c| matches!(c, DrawCommand::DrawRect { .. })).count();
        let oval_count = cmds.iter().filter(|c| matches!(c, DrawCommand::DrawOval { .. })).count();
        assert_eq!(rect_count, 2, "Expected 2 DrawRect commands");
        assert_eq!(oval_count, 1, "Expected 1 DrawOval command");
    }

    #[test]
    fn hidden_fill_skipped() {
        let mut shape = make_rect("r1", 0.0, 0.0, 100.0, 50.0, 0);
        shape.fills = vec![ShapeFill {
            color: 0xFF0000FF,
            opacity: 1.0,
            hidden: true,
            gradient: None,
        }];
        let tree = SceneTree::from_shapes(vec![shape]);
        let cmds = generate_draw_commands(&tree, &large_viewport(), &identity_view(), false);

        let has_fill = cmds.iter().any(|c| matches!(c, DrawCommand::DrawRect { .. }));
        assert!(!has_fill, "Hidden fill should not emit DrawRect");
    }

    #[test]
    fn hidden_stroke_skipped() {
        let mut shape = make_rect("r1", 0.0, 0.0, 100.0, 50.0, 0);
        shape.fills = vec![];
        shape.strokes = vec![ShapeStroke {
            color: 0xFF333333,
            width: 2.0,
            opacity: 1.0,
            hidden: true,
            alignment: StrokeAlignment::Center,
            cap: StrokeCap::Round,
            join: StrokeJoin::Round,
        }];
        let tree = SceneTree::from_shapes(vec![shape]);
        let cmds = generate_draw_commands(&tree, &large_viewport(), &identity_view(), false);

        let has_stroke = cmds.iter().any(|c| matches!(c, DrawCommand::DrawRRectStroke { .. }));
        assert!(!has_stroke, "Hidden stroke should not emit DrawRRectStroke");
    }

    #[test]
    fn apply_alpha_to_color_works() {
        assert_eq!(apply_alpha_to_color(0xFFFF0000, 0.5), 0x80FF0000);
        assert_eq!(apply_alpha_to_color(0xFFFF0000, 1.0), 0xFFFF0000);
        assert_eq!(apply_alpha_to_color(0xFFFF0000, 0.0), 0x00FF0000);
    }

    /// Comprehensive test: a clipping frame with 2 child shapes.
    /// Verifies children are rendered inside the clip.
    #[test]
    fn frame_with_children_emits_commands_for_all() {
        // Create a frame at (50, 50) with size 800x600, clip enabled
        let frame = make_frame("frame1", 50.0, 50.0, 800.0, 600.0, true);

        // Create child rectangle inside the frame
        let mut child_rect = make_rect("child_rect", 100.0, 100.0, 200.0, 100.0, 0);
        child_rect.frame_id = Some("frame1".to_string());

        // Create child ellipse inside the frame
        let mut child_ellipse = make_ellipse("child_ellipse", 300.0, 200.0, 150.0, 100.0);
        child_ellipse.frame_id = Some("frame1".to_string());
        child_ellipse.sort_order = 1;

        let tree = SceneTree::from_shapes(vec![frame, child_rect, child_ellipse]);
        let cmds = generate_draw_commands(&tree, &large_viewport(), &identity_view(), false);

        // Print all commands for debugging
        for (i, cmd) in cmds.iter().enumerate() {
            eprintln!("  cmd[{}]: {:?}", i, std::mem::discriminant(cmd));
            match cmd {
                DrawCommand::PushTransform { matrix } => {
                    eprintln!("    matrix: [{:.1}, {:.1}, {:.1}, {:.1}, {:.1}, {:.1}]",
                        matrix[0], matrix[1], matrix[2], matrix[3], matrix[4], matrix[5]);
                }
                DrawCommand::DrawRect { rect, color } => {
                    eprintln!("    rect: {:?}, color: 0x{:08X}", rect, color);
                }
                DrawCommand::DrawRRect { rect, radii, color } => {
                    eprintln!("    rect: {:?}, radii: {:?}, color: 0x{:08X}", rect, radii, color);
                }
                DrawCommand::DrawOval { rect, color } => {
                    eprintln!("    rect: {:?}, color: 0x{:08X}", rect, color);
                }
                DrawCommand::ClipRect { rect } => {
                    eprintln!("    clip_rect: {:?}", rect);
                }
                _ => {}
            }
        }

        // We expect:
        // - At least 1 DrawRect for the child_rect
        // - At least 1 DrawOval for the child_ellipse
        // - ClipRect for the frame
        let draw_rect_count = cmds.iter().filter(|c| matches!(c, DrawCommand::DrawRect { .. })).count();
        let draw_oval_count = cmds.iter().filter(|c| matches!(c, DrawCommand::DrawOval { .. })).count();
        let clip_count = cmds.iter().filter(|c| matches!(c, DrawCommand::ClipRect { .. })).count();

        assert!(draw_rect_count >= 1,
            "Expected at least 1 DrawRect for child_rect, got {draw_rect_count}. Total cmds: {}", cmds.len());
        assert!(draw_oval_count >= 1,
            "Expected at least 1 DrawOval for child_ellipse, got {draw_oval_count}. Total cmds: {}", cmds.len());
        assert!(clip_count >= 1,
            "Expected at least 1 ClipRect for the frame, got {clip_count}");
    }

    /// Test: a NON-clipping frame with child shapes.
    #[test]
    fn non_clipping_frame_with_children_emits_all() {
        let frame = make_frame("frame1", 0.0, 0.0, 400.0, 300.0, false);

        let mut child = make_rect("c1", 10.0, 10.0, 80.0, 60.0, 0);
        child.frame_id = Some("frame1".to_string());

        let tree = SceneTree::from_shapes(vec![frame, child]);
        let cmds = generate_draw_commands(&tree, &large_viewport(), &identity_view(), false);

        let draw_rect_count = cmds.iter().filter(|c| matches!(c, DrawCommand::DrawRect { .. })).count();
        assert!(draw_rect_count >= 1,
            "Expected DrawRect for child, got {draw_rect_count}. Total cmds: {}", cmds.len());
    }

    /// Test CanvasEngine end-to-end: load shapes then generate commands.
    #[test]
    fn engine_load_and_generate_integration() {
        use crate::api::engine::CanvasEngine;

        let mut engine = CanvasEngine::create();

        // Create shapes
        let frame = make_frame("f1", 0.0, 0.0, 800.0, 600.0, true);
        let mut child = make_rect("r1", 100.0, 100.0, 200.0, 100.0, 0);
        child.frame_id = Some("f1".to_string());
        let mut child2 = make_ellipse("e1", 300.0, 200.0, 150.0, 100.0);
        child2.frame_id = Some("f1".to_string());
        child2.sort_order = 1;

        // Load shapes into engine
        engine.load_all_shapes(vec![frame, child, child2]);

        // Generate draw commands
        let cmds = engine.generate_draw_commands(
            -1000.0, -1000.0, 2000.0, 2000.0,
            vec![1.0, 0.0, 0.0, 1.0, 0.0, 0.0],
            false,
            false,
        );

        eprintln!("Engine integration test: {} total commands", cmds.len());
        for (i, cmd) in cmds.iter().enumerate() {
            eprintln!("  cmd[{}]: {:?}", i, std::mem::discriminant(cmd));
        }

        let draw_rect_count = cmds.iter().filter(|c| matches!(c, DrawCommand::DrawRect { .. })).count();
        let draw_oval_count = cmds.iter().filter(|c| matches!(c, DrawCommand::DrawOval { .. })).count();

        assert!(draw_rect_count >= 1,
            "Expected DrawRect for child rectangle, got {draw_rect_count}. Total cmds: {}", cmds.len());
        assert!(draw_oval_count >= 1,
            "Expected DrawOval for child ellipse, got {draw_oval_count}. Total cmds: {}", cmds.len());
        assert!(cmds.len() >= 6,
            "Expected at least 6 cmds (view transform + frame + 2 children), got {}", cmds.len());
    }
}
