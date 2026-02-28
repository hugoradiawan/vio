use std::collections::HashMap;

use crate::scene_graph::shape::RenderShape;

/// Manages the parent-child hierarchy of shapes.
/// Provides efficient traversal and lookup by parent/frame.
pub struct SceneTree {
    /// All shapes by ID.
    shapes: HashMap<String, RenderShape>,
    /// Children IDs keyed by container (parent or frame) ID.
    children_by_container: HashMap<String, Vec<String>>,
    /// Root shape IDs (no parent and no frame).
    root_ids: Vec<String>,
}

impl SceneTree {
    pub fn new() -> Self {
        Self {
            shapes: HashMap::new(),
            children_by_container: HashMap::new(),
            root_ids: Vec::new(),
        }
    }

    /// Build from a list of shapes.
    pub fn from_shapes(shapes: Vec<RenderShape>) -> Self {
        let mut tree = Self::new();
        for shape in shapes {
            tree.insert(shape);
        }
        tree.sort_children();
        tree
    }

    /// Insert or update a shape.
    pub fn insert(&mut self, shape: RenderShape) {
        let id = shape.id.clone();

        // Remove from old container if updating
        if self.shapes.contains_key(&id) {
            self.remove_from_parent(&id);
        }

        // Determine container
        let container_id = shape
            .parent_id
            .clone()
            .or_else(|| shape.frame_id.clone());

        // Add to container's children or root
        match container_id {
            Some(cid) => {
                self.children_by_container
                    .entry(cid)
                    .or_default()
                    .push(id.clone());
            }
            None => {
                if !self.root_ids.contains(&id) {
                    self.root_ids.push(id.clone());
                }
            }
        }

        self.shapes.insert(id, shape);
    }

    /// Remove a shape by ID.
    pub fn remove(&mut self, id: &str) -> Option<RenderShape> {
        self.remove_from_parent(id);
        self.children_by_container.remove(id);
        self.shapes.remove(id)
    }

    /// Get a shape by ID.
    pub fn get(&self, id: &str) -> Option<&RenderShape> {
        self.shapes.get(id)
    }

    /// Get all shapes.
    pub fn all_shapes(&self) -> impl Iterator<Item = &RenderShape> {
        self.shapes.values()
    }

    /// Get the number of shapes.
    pub fn len(&self) -> usize {
        self.shapes.len()
    }

    /// Check if empty.
    pub fn is_empty(&self) -> bool {
        self.shapes.is_empty()
    }

    /// Get root shape IDs (sorted by sort_order).
    pub fn root_ids(&self) -> &[String] {
        &self.root_ids
    }

    /// Get children IDs for a container.
    pub fn children_of(&self, container_id: &str) -> &[String] {
        self.children_by_container
            .get(container_id)
            .map(|v| v.as_slice())
            .unwrap_or(&[])
    }

    /// Sort all children vectors by sort_order.
    pub fn sort_children(&mut self) {
        let shapes = &self.shapes;

        self.root_ids.sort_by(|a, b| {
            let sa = shapes.get(a).map(|s| s.sort_order).unwrap_or(0);
            let sb = shapes.get(b).map(|s| s.sort_order).unwrap_or(0);
            sa.cmp(&sb)
        });

        for children in self.children_by_container.values_mut() {
            children.sort_by(|a, b| {
                let sa = shapes.get(a).map(|s| s.sort_order).unwrap_or(0);
                let sb = shapes.get(b).map(|s| s.sort_order).unwrap_or(0);
                sa.cmp(&sb)
            });
        }
    }

    /// Depth-first traversal of the tree, returning shape IDs in paint order.
    pub fn depth_first_order(&self) -> Vec<String> {
        let mut result = Vec::with_capacity(self.shapes.len());
        for root_id in &self.root_ids {
            self.collect_depth_first(root_id, &mut result);
        }
        result
    }

    fn collect_depth_first(&self, id: &str, result: &mut Vec<String>) {
        result.push(id.to_string());
        for child_id in self.children_of(id) {
            self.collect_depth_first(child_id, result);
        }
    }

    fn remove_from_parent(&mut self, id: &str) {
        // Remove from root_ids
        self.root_ids.retain(|rid| rid != id);

        // Remove from any container's children
        if let Some(shape) = self.shapes.get(id) {
            let container_id = shape
                .parent_id
                .clone()
                .or_else(|| shape.frame_id.clone());
            if let Some(cid) = container_id {
                if let Some(children) = self.children_by_container.get_mut(&cid) {
                    children.retain(|cid| cid != id);
                }
            }
        }
    }
}

impl Default for SceneTree {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::math::matrix2d::Matrix2D;
    use crate::scene_graph::shape::*;

    fn make_shape(id: &str, sort_order: i32) -> RenderShape {
        RenderShape {
            id: id.to_string(),
            shape_type: ShapeType::Rectangle,
            transform: Matrix2D::identity(),
            parent_id: None,
            frame_id: None,
            sort_order,
            opacity: 1.0,
            hidden: false,
            rotation: 0.0,
            fills: vec![],
            strokes: vec![],
            shadow: None,
            blur: None,
            geometry: ShapeGeometry::Rectangle {
                width: 100.0,
                height: 100.0,
                r1: 0.0,
                r2: 0.0,
                r3: 0.0,
                r4: 0.0,
            },
        }
    }

    fn make_child(id: &str, parent_id: &str, sort_order: i32) -> RenderShape {
        let mut s = make_shape(id, sort_order);
        s.parent_id = Some(parent_id.to_string());
        s
    }

    #[test]
    fn insert_and_get() {
        let mut tree = SceneTree::new();
        tree.insert(make_shape("s1", 0));
        assert_eq!(tree.len(), 1);
        assert!(tree.get("s1").is_some());
        assert!(tree.get("s2").is_none());
    }

    #[test]
    fn root_shapes() {
        let mut tree = SceneTree::new();
        tree.insert(make_shape("s1", 1));
        tree.insert(make_shape("s2", 0));
        tree.sort_children();
        assert_eq!(tree.root_ids(), &["s2", "s1"]);
    }

    #[test]
    fn children_of_container() {
        let mut tree = SceneTree::new();
        tree.insert(make_shape("parent", 0));
        tree.insert(make_child("c1", "parent", 2));
        tree.insert(make_child("c2", "parent", 1));
        tree.sort_children();

        let children = tree.children_of("parent");
        assert_eq!(children, &["c2", "c1"]);
    }

    #[test]
    fn remove_shape() {
        let mut tree = SceneTree::new();
        tree.insert(make_shape("s1", 0));
        tree.insert(make_shape("s2", 1));
        tree.remove("s1");
        assert_eq!(tree.len(), 1);
        assert!(tree.get("s1").is_none());
        assert_eq!(tree.root_ids(), &["s2"]);
    }

    #[test]
    fn remove_child_from_parent() {
        let mut tree = SceneTree::new();
        tree.insert(make_shape("parent", 0));
        tree.insert(make_child("c1", "parent", 0));
        tree.insert(make_child("c2", "parent", 1));
        tree.remove("c1");
        assert_eq!(tree.children_of("parent"), &["c2"]);
    }

    #[test]
    fn depth_first_order() {
        let mut tree = SceneTree::new();
        tree.insert(make_shape("root1", 0));
        tree.insert(make_shape("root2", 1));
        tree.insert(make_child("c1", "root1", 0));
        tree.insert(make_child("c2", "root1", 1));
        tree.sort_children();

        let order = tree.depth_first_order();
        assert_eq!(order, vec!["root1", "c1", "c2", "root2"]);
    }

    #[test]
    fn update_existing_shape() {
        let mut tree = SceneTree::new();
        tree.insert(make_shape("s1", 0));
        let mut updated = make_shape("s1", 5);
        updated.opacity = 0.5;
        tree.insert(updated);
        assert_eq!(tree.len(), 1);
        assert_eq!(tree.get("s1").unwrap().opacity, 0.5);
    }

    #[test]
    fn empty_tree() {
        let tree = SceneTree::new();
        assert!(tree.is_empty());
        assert_eq!(tree.len(), 0);
        assert!(tree.root_ids().is_empty());
        assert_eq!(tree.depth_first_order(), Vec::<String>::new());
    }

    #[test]
    fn children_of_nonexistent_container() {
        let tree = SceneTree::new();
        assert!(tree.children_of("nope").is_empty());
    }

    #[test]
    fn frame_children_via_frame_id() {
        let mut tree = SceneTree::new();
        let mut frame = make_shape("frame1", 0);
        frame.shape_type = ShapeType::Frame;
        frame.geometry = ShapeGeometry::Frame {
            width: 200.0,
            height: 200.0,
            clip_content: true,
        };
        tree.insert(frame);

        let mut child = make_shape("child1", 0);
        child.frame_id = Some("frame1".to_string());
        tree.insert(child);

        assert_eq!(tree.children_of("frame1"), &["child1"]);
    }
}
