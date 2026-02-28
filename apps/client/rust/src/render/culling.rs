use crate::math::aabb::Aabb;
use crate::scene_graph::shape::RenderShape;

/// Check if a shape's world AABB is visible within the given viewport.
pub fn is_shape_visible(shape: &RenderShape, viewport: &Aabb) -> bool {
    if shape.hidden {
        return false;
    }
    let aabb = shape.world_aabb();
    let shape_aabb = Aabb::new(aabb.min_x, aabb.min_y, aabb.max_x, aabb.max_y);
    viewport.overlaps(&shape_aabb)
}

/// Check if a shape's world AABB is fully contained within the viewport.
pub fn is_shape_fully_visible(shape: &RenderShape, viewport: &Aabb) -> bool {
    if shape.hidden {
        return false;
    }
    let aabb = shape.world_aabb();
    let shape_aabb = Aabb::new(aabb.min_x, aabb.min_y, aabb.max_x, aabb.max_y);
    viewport.contains(&shape_aabb)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::math::matrix2d::Matrix2D;
    use crate::scene_graph::shape::*;

    fn make_shape_at(x: f64, y: f64, w: f64, h: f64) -> RenderShape {
        RenderShape {
            id: "test".to_string(),
            shape_type: ShapeType::Rectangle,
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

    #[test]
    fn visible_when_overlapping() {
        let shape = make_shape_at(50.0, 50.0, 100.0, 100.0);
        let viewport = Aabb::from_xywh(0.0, 0.0, 200.0, 200.0);
        assert!(is_shape_visible(&shape, &viewport));
    }

    #[test]
    fn not_visible_when_outside() {
        let shape = make_shape_at(500.0, 500.0, 100.0, 100.0);
        let viewport = Aabb::from_xywh(0.0, 0.0, 200.0, 200.0);
        assert!(!is_shape_visible(&shape, &viewport));
    }

    #[test]
    fn not_visible_when_hidden() {
        let mut shape = make_shape_at(50.0, 50.0, 100.0, 100.0);
        shape.hidden = true;
        let viewport = Aabb::from_xywh(0.0, 0.0, 200.0, 200.0);
        assert!(!is_shape_visible(&shape, &viewport));
    }

    #[test]
    fn partially_visible_is_visible() {
        let shape = make_shape_at(180.0, 180.0, 100.0, 100.0);
        let viewport = Aabb::from_xywh(0.0, 0.0, 200.0, 200.0);
        assert!(is_shape_visible(&shape, &viewport));
        assert!(!is_shape_fully_visible(&shape, &viewport));
    }

    #[test]
    fn fully_visible_when_inside() {
        let shape = make_shape_at(10.0, 10.0, 50.0, 50.0);
        let viewport = Aabb::from_xywh(0.0, 0.0, 200.0, 200.0);
        assert!(is_shape_fully_visible(&shape, &viewport));
    }

    #[test]
    fn rotated_shape_uses_aabb() {
        // A 100x20 rect rotated 45° at origin should have a larger AABB
        let mut shape = make_shape_at(0.0, 0.0, 100.0, 20.0);
        shape.transform = Matrix2D::rotation(45.0);
        let viewport = Aabb::from_xywh(-100.0, -100.0, 200.0, 200.0);
        assert!(is_shape_visible(&shape, &viewport));
    }
}
