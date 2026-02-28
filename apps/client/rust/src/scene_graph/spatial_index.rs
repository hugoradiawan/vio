use rstar::{RTree, RTreeObject, AABB};

use crate::scene_graph::shape::RenderShape;

/// Wraps a shape's world-space AABB for R-tree insertion.
#[derive(Debug, Clone)]
pub struct ShapeEnvelope {
    pub id: String,
    pub aabb: AABB<[f64; 2]>,
}

impl RTreeObject for ShapeEnvelope {
    type Envelope = AABB<[f64; 2]>;

    fn envelope(&self) -> Self::Envelope {
        self.aabb
    }
}

impl PartialEq for ShapeEnvelope {
    fn eq(&self, other: &Self) -> bool {
        self.id == other.id
    }
}

/// R-tree based spatial index for efficient viewport and hit-test queries.
pub struct SpatialIndex {
    tree: RTree<ShapeEnvelope>,
}

impl SpatialIndex {
    /// Create an empty spatial index.
    pub fn new() -> Self {
        Self {
            tree: RTree::new(),
        }
    }

    /// Bulk-load from a slice of shapes — O(n log n).
    pub fn build(shapes: &[RenderShape]) -> Self {
        let envelopes: Vec<ShapeEnvelope> = shapes
            .iter()
            .filter(|s| !s.hidden)
            .map(Self::shape_to_envelope)
            .collect();
        Self {
            tree: RTree::bulk_load(envelopes),
        }
    }

    /// Insert a single shape.
    pub fn insert(&mut self, shape: &RenderShape) {
        if shape.hidden {
            return;
        }
        self.tree.insert(Self::shape_to_envelope(shape));
    }

    /// Remove a shape by ID. Returns true if found and removed.
    pub fn remove(&mut self, id: &str) -> bool {
        // R-tree doesn't support removal by key, so we locate and remove
        let to_remove: Vec<ShapeEnvelope> = self
            .tree
            .iter()
            .filter(|e| e.id == id)
            .cloned()
            .collect();

        let mut removed = false;
        for envelope in to_remove {
            self.tree.remove(&envelope);
            removed = true;
        }
        removed
    }

    /// Update a shape: remove old entry, insert new one.
    pub fn update(&mut self, shape: &RenderShape) {
        self.remove(&shape.id);
        self.insert(shape);
    }

    /// Query all shape IDs whose AABBs overlap the given viewport rectangle.
    pub fn query_visible(
        &self,
        min_x: f64,
        min_y: f64,
        max_x: f64,
        max_y: f64,
    ) -> Vec<String> {
        let query_aabb = AABB::from_corners([min_x, min_y], [max_x, max_y]);
        self.tree
            .locate_in_envelope_intersecting(&query_aabb)
            .map(|e| e.id.clone())
            .collect()
    }

    /// Query all shape IDs whose AABBs contain the given point.
    pub fn query_point(&self, x: f64, y: f64) -> Vec<String> {
        // Use a tiny AABB around the point for envelope intersection query
        let point_aabb = AABB::from_corners([x, y], [x, y]);
        self.tree
            .locate_in_envelope_intersecting(&point_aabb)
            .map(|e| e.id.clone())
            .collect()
    }

    /// Get the total number of indexed shapes.
    pub fn len(&self) -> usize {
        self.tree.size()
    }

    /// Check if the index is empty.
    pub fn is_empty(&self) -> bool {
        self.tree.size() == 0
    }

    fn shape_to_envelope(shape: &RenderShape) -> ShapeEnvelope {
        let aabb = shape.world_aabb();
        ShapeEnvelope {
            id: shape.id.clone(),
            aabb: AABB::from_corners(
                [aabb.min_x, aabb.min_y],
                [aabb.max_x, aabb.max_y],
            ),
        }
    }
}

impl Default for SpatialIndex {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::math::matrix2d::Matrix2D;
    use crate::scene_graph::shape::*;

    fn make_shape_at(id: &str, x: f64, y: f64, w: f64, h: f64) -> RenderShape {
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
    fn build_from_shapes() {
        let shapes = vec![
            make_shape_at("s1", 0.0, 0.0, 100.0, 100.0),
            make_shape_at("s2", 200.0, 200.0, 50.0, 50.0),
        ];
        let index = SpatialIndex::build(&shapes);
        assert_eq!(index.len(), 2);
    }

    #[test]
    fn query_visible_finds_overlapping() {
        let shapes = vec![
            make_shape_at("s1", 0.0, 0.0, 100.0, 100.0),
            make_shape_at("s2", 200.0, 200.0, 50.0, 50.0),
            make_shape_at("s3", 500.0, 500.0, 50.0, 50.0),
        ];
        let index = SpatialIndex::build(&shapes);

        // viewport covers first two shapes
        let visible = index.query_visible(-10.0, -10.0, 260.0, 260.0);
        assert!(visible.contains(&"s1".to_string()));
        assert!(visible.contains(&"s2".to_string()));
        assert!(!visible.contains(&"s3".to_string()));
    }

    #[test]
    fn query_visible_empty_viewport() {
        let shapes = vec![make_shape_at("s1", 0.0, 0.0, 100.0, 100.0)];
        let index = SpatialIndex::build(&shapes);
        let visible = index.query_visible(500.0, 500.0, 600.0, 600.0);
        assert!(visible.is_empty());
    }

    #[test]
    fn query_point_finds_containing() {
        let shapes = vec![
            make_shape_at("s1", 0.0, 0.0, 100.0, 100.0),
            make_shape_at("s2", 50.0, 50.0, 100.0, 100.0),
        ];
        let index = SpatialIndex::build(&shapes);

        // Point inside both shapes
        let hits = index.query_point(75.0, 75.0);
        assert!(hits.contains(&"s1".to_string()));
        assert!(hits.contains(&"s2".to_string()));

        // Point only inside s1
        let hits = index.query_point(10.0, 10.0);
        assert!(hits.contains(&"s1".to_string()));
        assert!(!hits.contains(&"s2".to_string()));
    }

    #[test]
    fn insert_and_query() {
        let mut index = SpatialIndex::new();
        index.insert(&make_shape_at("s1", 0.0, 0.0, 100.0, 100.0));
        assert_eq!(index.len(), 1);

        let visible = index.query_visible(-10.0, -10.0, 110.0, 110.0);
        assert_eq!(visible, vec!["s1".to_string()]);
    }

    #[test]
    fn remove_shape() {
        let shapes = vec![
            make_shape_at("s1", 0.0, 0.0, 100.0, 100.0),
            make_shape_at("s2", 200.0, 200.0, 50.0, 50.0),
        ];
        let mut index = SpatialIndex::build(&shapes);
        assert!(index.remove("s1"));
        assert_eq!(index.len(), 1);

        let visible = index.query_visible(-10.0, -10.0, 110.0, 110.0);
        assert!(visible.is_empty());
    }

    #[test]
    fn remove_nonexistent_returns_false() {
        let mut index = SpatialIndex::new();
        assert!(!index.remove("nope"));
    }

    #[test]
    fn update_shape_position() {
        let mut index = SpatialIndex::new();
        index.insert(&make_shape_at("s1", 0.0, 0.0, 100.0, 100.0));

        // Move shape to new position
        index.update(&make_shape_at("s1", 500.0, 500.0, 100.0, 100.0));

        // Old position should not find it
        let visible = index.query_visible(-10.0, -10.0, 110.0, 110.0);
        assert!(visible.is_empty());

        // New position should
        let visible = index.query_visible(490.0, 490.0, 610.0, 610.0);
        assert_eq!(visible, vec!["s1".to_string()]);
    }

    #[test]
    fn hidden_shapes_not_indexed() {
        let mut shape = make_shape_at("s1", 0.0, 0.0, 100.0, 100.0);
        shape.hidden = true;
        let index = SpatialIndex::build(&[shape]);
        assert_eq!(index.len(), 0);
    }

    #[test]
    fn empty_index() {
        let index = SpatialIndex::new();
        assert!(index.is_empty());
        assert_eq!(index.len(), 0);
        assert!(index.query_visible(0.0, 0.0, 100.0, 100.0).is_empty());
        assert!(index.query_point(50.0, 50.0).is_empty());
    }

    #[test]
    fn large_number_of_shapes() {
        let shapes: Vec<RenderShape> = (0..1000)
            .map(|i| {
                let x = (i % 100) as f64 * 20.0;
                let y = (i / 100) as f64 * 20.0;
                make_shape_at(&format!("s{i}"), x, y, 15.0, 15.0)
            })
            .collect();
        let index = SpatialIndex::build(&shapes);
        assert_eq!(index.len(), 1000);

        // Query a small viewport
        let visible = index.query_visible(0.0, 0.0, 50.0, 50.0);
        assert!(!visible.is_empty());
        assert!(visible.len() < 100); // Should be much fewer than 1000
    }
}
