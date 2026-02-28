use crate::scene_graph::shape::RenderShape;
use crate::scene_graph::spatial_index::SpatialIndex;
use crate::scene_graph::tree::SceneTree;

/// The main canvas engine, exposed to Dart as an opaque Rust type.
///
/// Owns the scene graph, spatial index, and provides APIs for:
/// - Syncing shape data from Dart
/// - Querying visible shapes for a viewport
/// - Hit testing
///
/// In Phase 2, this will also generate draw commands.
pub struct CanvasEngine {
    tree: SceneTree,
    spatial_index: SpatialIndex,
    dirty: bool,
}

impl CanvasEngine {
    /// Create a new empty engine instance.
    #[flutter_rust_bridge::frb(sync)]
    pub fn create() -> CanvasEngine {
        CanvasEngine {
            tree: SceneTree::new(),
            spatial_index: SpatialIndex::new(),
            dirty: false,
        }
    }

    /// Sync a batch of shape changes from Dart → Rust.
    /// Called when CanvasBloc emits a new state.
    pub fn sync_shapes(
        &mut self,
        added: Vec<RenderShape>,
        updated: Vec<RenderShape>,
        removed: Vec<String>,
    ) {
        // Remove
        for id in &removed {
            self.tree.remove(id);
            self.spatial_index.remove(id);
        }

        // Add
        for shape in &added {
            self.tree.insert(shape.clone());
            self.spatial_index.insert(shape);
        }

        // Update
        for shape in &updated {
            self.tree.insert(shape.clone());
            self.spatial_index.update(shape);
        }

        if !added.is_empty() || !updated.is_empty() || !removed.is_empty() {
            self.tree.sort_children();
            self.dirty = true;
        }
    }

    /// Bulk-load all shapes (full sync). Replaces the entire scene.
    pub fn load_all_shapes(&mut self, shapes: Vec<RenderShape>) {
        self.spatial_index = SpatialIndex::build(&shapes);
        self.tree = SceneTree::from_shapes(shapes);
        self.dirty = true;
    }

    /// Query shape IDs visible within a viewport rectangle.
    #[flutter_rust_bridge::frb(sync)]
    pub fn query_visible(
        &self,
        viewport_min_x: f64,
        viewport_min_y: f64,
        viewport_max_x: f64,
        viewport_max_y: f64,
    ) -> Vec<String> {
        self.spatial_index
            .query_visible(viewport_min_x, viewport_min_y, viewport_max_x, viewport_max_y)
    }

    /// Hit test: find all shape IDs at a point (in canvas coordinates).
    /// Returns IDs sorted by z-order (topmost first).
    #[flutter_rust_bridge::frb(sync)]
    pub fn hit_test_point(&self, x: f64, y: f64) -> Vec<String> {
        let candidate_ids = self.spatial_index.query_point(x, y);

        // Filter candidates by precise geometry test
        let mut hits: Vec<(&RenderShape, i32)> = candidate_ids
            .iter()
            .filter_map(|id| self.tree.get(id))
            .filter(|shape| self.point_in_shape(shape, x, y))
            .map(|shape| (shape, shape.sort_order))
            .collect();

        // Sort by sort_order descending (topmost first)
        hits.sort_by(|a, b| b.1.cmp(&a.1));
        hits.iter().map(|(s, _)| s.id.clone()).collect()
    }

    /// Hit test: find all shape IDs overlapping a rectangle (for drag-select).
    #[flutter_rust_bridge::frb(sync)]
    pub fn hit_test_rect(
        &self,
        x: f64,
        y: f64,
        w: f64,
        h: f64,
    ) -> Vec<String> {
        self.spatial_index.query_visible(x, y, x + w, y + h)
    }

    /// Get shape count.
    #[flutter_rust_bridge::frb(sync)]
    pub fn shape_count(&self) -> usize {
        self.tree.len()
    }

    /// Get depth-first shape IDs in paint order.
    #[flutter_rust_bridge::frb(sync)]
    pub fn paint_order(&self) -> Vec<String> {
        self.tree.depth_first_order()
    }

    /// Precise point-in-shape geometry test.
    /// Transforms the point into shape-local coordinates and checks bounds.
    fn point_in_shape(&self, shape: &RenderShape, world_x: f64, world_y: f64) -> bool {
        // Transform point to shape-local coords
        let inv = match shape.transform.invert() {
            Some(inv) => inv,
            None => return false,
        };
        let (lx, ly) = inv.transform_point(world_x, world_y);
        let (w, h) = shape.geometry.dimensions();

        // Basic bounding box check in local coords
        if lx < 0.0 || ly < 0.0 || lx > w || ly > h {
            return false;
        }

        // Geometry-specific check
        match &shape.geometry {
            crate::scene_graph::shape::ShapeGeometry::Ellipse { width, height } => {
                // Ellipse hit test: ((x - cx)/rx)^2 + ((y - cy)/ry)^2 <= 1
                let rx = width / 2.0;
                let ry = height / 2.0;
                let cx = rx;
                let cy = ry;
                let dx = (lx - cx) / rx;
                let dy = (ly - cy) / ry;
                dx * dx + dy * dy <= 1.0
            }
            _ => true, // Rectangle/Frame/Text/Image all use bounding box
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::math::matrix2d::Matrix2D;
    use crate::scene_graph::shape::*;

    fn rect(id: &str, x: f64, y: f64, w: f64, h: f64, sort: i32) -> RenderShape {
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

    fn ellipse(id: &str, x: f64, y: f64, w: f64, h: f64) -> RenderShape {
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
            fills: vec![],
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
    fn create_engine() {
        let engine = CanvasEngine::create();
        assert_eq!(engine.shape_count(), 0);
    }

    #[test]
    fn load_all_shapes() {
        let mut engine = CanvasEngine::create();
        engine.load_all_shapes(vec![
            rect("r1", 0.0, 0.0, 100.0, 100.0, 0),
            rect("r2", 200.0, 200.0, 50.0, 50.0, 1),
        ]);
        assert_eq!(engine.shape_count(), 2);
    }

    #[test]
    fn sync_add_update_remove() {
        let mut engine = CanvasEngine::create();

        // Add
        engine.sync_shapes(
            vec![rect("r1", 0.0, 0.0, 100.0, 100.0, 0)],
            vec![],
            vec![],
        );
        assert_eq!(engine.shape_count(), 1);

        // Update
        engine.sync_shapes(
            vec![],
            vec![rect("r1", 50.0, 50.0, 100.0, 100.0, 0)],
            vec![],
        );
        assert_eq!(engine.shape_count(), 1);

        // Remove
        engine.sync_shapes(vec![], vec![], vec!["r1".to_string()]);
        assert_eq!(engine.shape_count(), 0);
    }

    #[test]
    fn query_visible_shapes() {
        let mut engine = CanvasEngine::create();
        engine.load_all_shapes(vec![
            rect("r1", 0.0, 0.0, 100.0, 100.0, 0),
            rect("r2", 500.0, 500.0, 50.0, 50.0, 1),
        ]);

        let visible = engine.query_visible(0.0, 0.0, 200.0, 200.0);
        assert!(visible.contains(&"r1".to_string()));
        assert!(!visible.contains(&"r2".to_string()));
    }

    #[test]
    fn hit_test_point_rect() {
        let mut engine = CanvasEngine::create();
        engine.load_all_shapes(vec![
            rect("behind", 0.0, 0.0, 100.0, 100.0, 0),
            rect("front", 50.0, 50.0, 100.0, 100.0, 1),
        ]);

        let hits = engine.hit_test_point(75.0, 75.0);
        assert_eq!(hits.len(), 2);
        assert_eq!(hits[0], "front"); // topmost first
        assert_eq!(hits[1], "behind");
    }

    #[test]
    fn hit_test_point_miss() {
        let mut engine = CanvasEngine::create();
        engine.load_all_shapes(vec![rect("r1", 0.0, 0.0, 100.0, 100.0, 0)]);

        let hits = engine.hit_test_point(200.0, 200.0);
        assert!(hits.is_empty());
    }

    #[test]
    fn hit_test_ellipse_precise() {
        let mut engine = CanvasEngine::create();
        engine.load_all_shapes(vec![ellipse("e1", 0.0, 0.0, 100.0, 100.0)]);

        // Center — should hit
        assert!(!engine.hit_test_point(50.0, 50.0).is_empty());

        // Corner of bounding box — should miss (outside ellipse)
        assert!(engine.hit_test_point(1.0, 1.0).is_empty());
    }

    #[test]
    fn hit_test_rect_selection() {
        let mut engine = CanvasEngine::create();
        engine.load_all_shapes(vec![
            rect("r1", 0.0, 0.0, 100.0, 100.0, 0),
            rect("r2", 200.0, 200.0, 50.0, 50.0, 1),
            rect("r3", 500.0, 500.0, 50.0, 50.0, 2),
        ]);

        let hits = engine.hit_test_rect(0.0, 0.0, 260.0, 260.0);
        assert!(hits.contains(&"r1".to_string()));
        assert!(hits.contains(&"r2".to_string()));
        assert!(!hits.contains(&"r3".to_string()));
    }

    #[test]
    fn paint_order() {
        let mut engine = CanvasEngine::create();
        engine.load_all_shapes(vec![
            rect("r2", 0.0, 0.0, 100.0, 100.0, 2),
            rect("r1", 0.0, 0.0, 100.0, 100.0, 1),
            rect("r3", 0.0, 0.0, 100.0, 100.0, 3),
        ]);

        let order = engine.paint_order();
        assert_eq!(order, vec!["r1", "r2", "r3"]);
    }
}
