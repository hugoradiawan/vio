/// Axis-Aligned Bounding Box for 2D space.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Aabb {
    pub min_x: f64,
    pub min_y: f64,
    pub max_x: f64,
    pub max_y: f64,
}

impl Aabb {
    pub fn new(min_x: f64, min_y: f64, max_x: f64, max_y: f64) -> Self {
        Self {
            min_x,
            min_y,
            max_x,
            max_y,
        }
    }

    /// Create from (x, y, width, height).
    pub fn from_xywh(x: f64, y: f64, w: f64, h: f64) -> Self {
        Self {
            min_x: x,
            min_y: y,
            max_x: x + w,
            max_y: y + h,
        }
    }

    pub fn width(&self) -> f64 {
        self.max_x - self.min_x
    }

    pub fn height(&self) -> f64 {
        self.max_y - self.min_y
    }

    pub fn center_x(&self) -> f64 {
        (self.min_x + self.max_x) * 0.5
    }

    pub fn center_y(&self) -> f64 {
        (self.min_y + self.max_y) * 0.5
    }

    /// Test if this AABB overlaps another.
    pub fn overlaps(&self, other: &Aabb) -> bool {
        self.min_x < other.max_x
            && self.max_x > other.min_x
            && self.min_y < other.max_y
            && self.max_y > other.min_y
    }

    /// Test if this AABB fully contains another.
    pub fn contains(&self, other: &Aabb) -> bool {
        self.min_x <= other.min_x
            && self.min_y <= other.min_y
            && self.max_x >= other.max_x
            && self.max_y >= other.max_y
    }

    /// Test if a point is inside this AABB.
    pub fn contains_point(&self, x: f64, y: f64) -> bool {
        x >= self.min_x && x <= self.max_x && y >= self.min_y && y <= self.max_y
    }

    /// Return the union of two AABBs (smallest AABB that contains both).
    pub fn union(&self, other: &Aabb) -> Aabb {
        Aabb {
            min_x: self.min_x.min(other.min_x),
            min_y: self.min_y.min(other.min_y),
            max_x: self.max_x.max(other.max_x),
            max_y: self.max_y.max(other.max_y),
        }
    }

    /// Return the intersection of two AABBs, or None if they don't overlap.
    pub fn intersection(&self, other: &Aabb) -> Option<Aabb> {
        let result = Aabb {
            min_x: self.min_x.max(other.min_x),
            min_y: self.min_y.max(other.min_y),
            max_x: self.max_x.min(other.max_x),
            max_y: self.max_y.min(other.max_y),
        };
        if result.min_x < result.max_x && result.min_y < result.max_y {
            Some(result)
        } else {
            None
        }
    }

    /// Inflate the AABB by `amount` on all sides.
    pub fn inflate(&self, amount: f64) -> Aabb {
        Aabb {
            min_x: self.min_x - amount,
            min_y: self.min_y - amount,
            max_x: self.max_x + amount,
            max_y: self.max_y + amount,
        }
    }

    /// Return an empty (invalid) AABB.
    pub fn empty() -> Self {
        Self {
            min_x: f64::INFINITY,
            min_y: f64::INFINITY,
            max_x: f64::NEG_INFINITY,
            max_y: f64::NEG_INFINITY,
        }
    }

    /// Check if AABB is empty (invalid).
    pub fn is_empty(&self) -> bool {
        self.min_x > self.max_x || self.min_y > self.max_y
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn from_xywh_correctness() {
        let a = Aabb::from_xywh(10.0, 20.0, 100.0, 50.0);
        assert_eq!(a.min_x, 10.0);
        assert_eq!(a.min_y, 20.0);
        assert_eq!(a.max_x, 110.0);
        assert_eq!(a.max_y, 70.0);
    }

    #[test]
    fn width_and_height() {
        let a = Aabb::from_xywh(0.0, 0.0, 100.0, 50.0);
        assert_eq!(a.width(), 100.0);
        assert_eq!(a.height(), 50.0);
    }

    #[test]
    fn center() {
        let a = Aabb::from_xywh(10.0, 20.0, 100.0, 50.0);
        assert_eq!(a.center_x(), 60.0);
        assert_eq!(a.center_y(), 45.0);
    }

    #[test]
    fn overlaps_true() {
        let a = Aabb::from_xywh(0.0, 0.0, 100.0, 100.0);
        let b = Aabb::from_xywh(50.0, 50.0, 100.0, 100.0);
        assert!(a.overlaps(&b));
        assert!(b.overlaps(&a));
    }

    #[test]
    fn overlaps_false() {
        let a = Aabb::from_xywh(0.0, 0.0, 100.0, 100.0);
        let b = Aabb::from_xywh(200.0, 200.0, 50.0, 50.0);
        assert!(!a.overlaps(&b));
        assert!(!b.overlaps(&a));
    }

    #[test]
    fn overlaps_edge_touching_is_false() {
        let a = Aabb::from_xywh(0.0, 0.0, 100.0, 100.0);
        let b = Aabb::from_xywh(100.0, 0.0, 100.0, 100.0);
        assert!(!a.overlaps(&b)); // edge-touching is not overlapping
    }

    #[test]
    fn contains_fully_inside() {
        let a = Aabb::from_xywh(0.0, 0.0, 100.0, 100.0);
        let b = Aabb::from_xywh(10.0, 10.0, 20.0, 20.0);
        assert!(a.contains(&b));
        assert!(!b.contains(&a));
    }

    #[test]
    fn contains_point_inside() {
        let a = Aabb::from_xywh(0.0, 0.0, 100.0, 100.0);
        assert!(a.contains_point(50.0, 50.0));
        assert!(a.contains_point(0.0, 0.0)); // edge
        assert!(!a.contains_point(-1.0, 50.0));
    }

    #[test]
    fn union_merges() {
        let a = Aabb::from_xywh(0.0, 0.0, 50.0, 50.0);
        let b = Aabb::from_xywh(100.0, 100.0, 50.0, 50.0);
        let u = a.union(&b);
        assert_eq!(u.min_x, 0.0);
        assert_eq!(u.min_y, 0.0);
        assert_eq!(u.max_x, 150.0);
        assert_eq!(u.max_y, 150.0);
    }

    #[test]
    fn intersection_overlapping() {
        let a = Aabb::from_xywh(0.0, 0.0, 100.0, 100.0);
        let b = Aabb::from_xywh(50.0, 50.0, 100.0, 100.0);
        let i = a.intersection(&b).expect("should intersect");
        assert_eq!(i.min_x, 50.0);
        assert_eq!(i.min_y, 50.0);
        assert_eq!(i.max_x, 100.0);
        assert_eq!(i.max_y, 100.0);
    }

    #[test]
    fn intersection_disjoint_is_none() {
        let a = Aabb::from_xywh(0.0, 0.0, 50.0, 50.0);
        let b = Aabb::from_xywh(100.0, 100.0, 50.0, 50.0);
        assert!(a.intersection(&b).is_none());
    }

    #[test]
    fn inflate_expands() {
        let a = Aabb::from_xywh(10.0, 10.0, 100.0, 100.0);
        let inflated = a.inflate(5.0);
        assert_eq!(inflated.min_x, 5.0);
        assert_eq!(inflated.min_y, 5.0);
        assert_eq!(inflated.max_x, 115.0);
        assert_eq!(inflated.max_y, 115.0);
    }

    #[test]
    fn empty_aabb_is_empty() {
        let a = Aabb::empty();
        assert!(a.is_empty());
    }

    #[test]
    fn normal_aabb_is_not_empty() {
        let a = Aabb::from_xywh(0.0, 0.0, 10.0, 10.0);
        assert!(!a.is_empty());
    }
}
