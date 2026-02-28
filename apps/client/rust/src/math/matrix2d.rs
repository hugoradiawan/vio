/// A 2D affine transformation matrix with 6 parameters:
/// ```text
/// | a  c  e |
/// | b  d  f |
/// | 0  0  1 |
/// ```
/// Mirrors `packages/core/lib/src/models/matrix2d.dart`.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Matrix2D {
    pub a: f64,
    pub b: f64,
    pub c: f64,
    pub d: f64,
    pub e: f64,
    pub f: f64,
}

impl Matrix2D {
    pub fn new(a: f64, b: f64, c: f64, d: f64, e: f64, f: f64) -> Self {
        Self { a, b, c, d, e, f }
    }

    pub fn identity() -> Self {
        Self {
            a: 1.0,
            b: 0.0,
            c: 0.0,
            d: 1.0,
            e: 0.0,
            f: 0.0,
        }
    }

    pub fn translation(tx: f64, ty: f64) -> Self {
        Self {
            a: 1.0,
            b: 0.0,
            c: 0.0,
            d: 1.0,
            e: tx,
            f: ty,
        }
    }

    pub fn scale(sx: f64, sy: f64) -> Self {
        Self {
            a: sx,
            b: 0.0,
            c: 0.0,
            d: sy,
            e: 0.0,
            f: 0.0,
        }
    }

    /// Rotation by `angle_deg` degrees (counterclockwise).
    pub fn rotation(angle_deg: f64) -> Self {
        let rad = angle_deg.to_radians();
        let cos = rad.cos();
        let sin = rad.sin();
        Self {
            a: cos,
            b: sin,
            c: -sin,
            d: cos,
            e: 0.0,
            f: 0.0,
        }
    }

    /// Rotation around a center point.
    pub fn rotation_at(angle_deg: f64, cx: f64, cy: f64) -> Self {
        let translate_to_origin = Self::translation(-cx, -cy);
        let rotate = Self::rotation(angle_deg);
        let translate_back = Self::translation(cx, cy);
        translate_back.multiply(&rotate.multiply(&translate_to_origin))
    }

    /// Matrix multiplication: self * other
    pub fn multiply(&self, other: &Matrix2D) -> Matrix2D {
        Matrix2D {
            a: self.a * other.a + self.c * other.b,
            b: self.b * other.a + self.d * other.b,
            c: self.a * other.c + self.c * other.d,
            d: self.b * other.c + self.d * other.d,
            e: self.a * other.e + self.c * other.f + self.e,
            f: self.b * other.e + self.d * other.f + self.f,
        }
    }

    /// Determinant of the 2x2 linear part.
    pub fn determinant(&self) -> f64 {
        self.a * self.d - self.b * self.c
    }

    /// Invert the matrix. Returns None if singular (determinant == 0).
    pub fn invert(&self) -> Option<Matrix2D> {
        let det = self.determinant();
        if det.abs() < 1e-15 {
            return None;
        }
        let inv_det = 1.0 / det;
        Some(Matrix2D {
            a: self.d * inv_det,
            b: -self.b * inv_det,
            c: -self.c * inv_det,
            d: self.a * inv_det,
            e: (self.c * self.f - self.d * self.e) * inv_det,
            f: (self.b * self.e - self.a * self.f) * inv_det,
        })
    }

    /// Transform a point (x, y) by this matrix.
    pub fn transform_point(&self, x: f64, y: f64) -> (f64, f64) {
        (
            self.a * x + self.c * y + self.e,
            self.b * x + self.d * y + self.f,
        )
    }

    /// Transform all 4 corners of a rectangle and return the axis-aligned bounding box.
    pub fn transform_rect(&self, x: f64, y: f64, w: f64, h: f64) -> (f64, f64, f64, f64) {
        let corners = [
            self.transform_point(x, y),
            self.transform_point(x + w, y),
            self.transform_point(x + w, y + h),
            self.transform_point(x, y + h),
        ];
        let min_x = corners.iter().map(|c| c.0).fold(f64::INFINITY, f64::min);
        let min_y = corners.iter().map(|c| c.1).fold(f64::INFINITY, f64::min);
        let max_x = corners.iter().map(|c| c.0).fold(f64::NEG_INFINITY, f64::max);
        let max_y = corners.iter().map(|c| c.1).fold(f64::NEG_INFINITY, f64::max);
        (min_x, min_y, max_x - min_x, max_y - min_y)
    }

    /// Convert to a flat array [a, b, c, d, e, f] for FFI transfer.
    pub fn to_array(&self) -> [f64; 6] {
        [self.a, self.b, self.c, self.d, self.e, self.f]
    }

    /// Create from a flat array [a, b, c, d, e, f].
    pub fn from_array(arr: &[f64; 6]) -> Self {
        Self {
            a: arr[0],
            b: arr[1],
            c: arr[2],
            d: arr[3],
            e: arr[4],
            f: arr[5],
        }
    }
}

impl Default for Matrix2D {
    fn default() -> Self {
        Self::identity()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const EPSILON: f64 = 1e-10;

    fn assert_near(a: f64, b: f64) {
        assert!(
            (a - b).abs() < EPSILON,
            "expected {b}, got {a} (diff={})",
            (a - b).abs()
        );
    }

    #[test]
    fn identity_transform_preserves_point() {
        let m = Matrix2D::identity();
        let (x, y) = m.transform_point(10.0, 20.0);
        assert_near(x, 10.0);
        assert_near(y, 20.0);
    }

    #[test]
    fn translation_moves_point() {
        let m = Matrix2D::translation(100.0, 200.0);
        let (x, y) = m.transform_point(10.0, 20.0);
        assert_near(x, 110.0);
        assert_near(y, 220.0);
    }

    #[test]
    fn scale_multiplies_coords() {
        let m = Matrix2D::scale(2.0, 3.0);
        let (x, y) = m.transform_point(5.0, 10.0);
        assert_near(x, 10.0);
        assert_near(y, 30.0);
    }

    #[test]
    fn rotation_90_degrees() {
        let m = Matrix2D::rotation(90.0);
        let (x, y) = m.transform_point(1.0, 0.0);
        assert_near(x, 0.0);
        assert_near(y, 1.0);
    }

    #[test]
    fn rotation_180_degrees() {
        let m = Matrix2D::rotation(180.0);
        let (x, y) = m.transform_point(1.0, 0.0);
        assert_near(x, -1.0);
        assert_near(y, 0.0);
    }

    #[test]
    fn rotation_at_center() {
        let m = Matrix2D::rotation_at(90.0, 50.0, 50.0);
        let (x, y) = m.transform_point(100.0, 50.0);
        assert_near(x, 50.0);
        assert_near(y, 100.0);
    }

    #[test]
    fn multiply_translation_and_scale() {
        let t = Matrix2D::translation(10.0, 20.0);
        let s = Matrix2D::scale(2.0, 3.0);
        let m = t.multiply(&s); // first scale, then translate
        let (x, y) = m.transform_point(5.0, 5.0);
        assert_near(x, 20.0); // 5*2 + 10
        assert_near(y, 35.0); // 5*3 + 20
    }

    #[test]
    fn multiply_then_invert_is_identity() {
        let m = Matrix2D::new(2.0, 0.5, -0.3, 1.5, 100.0, 200.0);
        let inv = m.invert().expect("should be invertible");
        let result = m.multiply(&inv);
        assert_near(result.a, 1.0);
        assert_near(result.b, 0.0);
        assert_near(result.c, 0.0);
        assert_near(result.d, 1.0);
        assert_near(result.e, 0.0);
        assert_near(result.f, 0.0);
    }

    #[test]
    fn invert_identity_is_identity() {
        let m = Matrix2D::identity();
        let inv = m.invert().unwrap();
        assert_near(inv.a, 1.0);
        assert_near(inv.d, 1.0);
        assert_near(inv.e, 0.0);
    }

    #[test]
    fn invert_singular_returns_none() {
        let m = Matrix2D::new(0.0, 0.0, 0.0, 0.0, 10.0, 20.0);
        assert!(m.invert().is_none());
    }

    #[test]
    fn determinant_of_identity_is_one() {
        assert_near(Matrix2D::identity().determinant(), 1.0);
    }

    #[test]
    fn determinant_of_scale() {
        let m = Matrix2D::scale(3.0, 4.0);
        assert_near(m.determinant(), 12.0);
    }

    #[test]
    fn transform_rect_identity() {
        let m = Matrix2D::identity();
        let (x, y, w, h) = m.transform_rect(10.0, 20.0, 100.0, 50.0);
        assert_near(x, 10.0);
        assert_near(y, 20.0);
        assert_near(w, 100.0);
        assert_near(h, 50.0);
    }

    #[test]
    fn transform_rect_with_rotation_expands_bbox() {
        let m = Matrix2D::rotation(45.0);
        let (_, _, w, h) = m.transform_rect(0.0, 0.0, 100.0, 0.0);
        // A 100-wide horizontal line rotated 45° should have equal width and height
        let expected = 100.0 * (45.0_f64.to_radians().cos());
        assert_near(w, expected);
        assert_near(h, expected);
    }

    #[test]
    fn to_array_and_from_array_roundtrip() {
        let m = Matrix2D::new(1.0, 2.0, 3.0, 4.0, 5.0, 6.0);
        let arr = m.to_array();
        let m2 = Matrix2D::from_array(&arr);
        assert_eq!(m, m2);
    }

    #[test]
    fn default_is_identity() {
        assert_eq!(Matrix2D::default(), Matrix2D::identity());
    }
}
