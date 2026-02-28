use crate::math::matrix2d::Matrix2D;

/// Mirrors the Dart `ShapeType` enum from packages/core.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ShapeType {
    Rectangle,
    Ellipse,
    Text,
    Frame,
    Group,
    Path,
    Image,
    Svg,
    Bool,
}

/// Text alignment, mirrors Dart's `TextAlign`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TextAlign {
    Left,
    Center,
    Right,
    Justify,
}

/// Boolean operation type.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BoolOp {
    Union,
    Subtract,
    Intersect,
    Exclude,
}

/// Stroke alignment relative to path.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StrokeAlignment {
    Center,
    Inside,
    Outside,
}

/// Gradient type.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GradientType {
    Linear,
    Radial,
}

/// Shadow style.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ShadowStyle {
    Drop,
    Inner,
}

/// Blur type.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BlurType {
    Layer,
    Background,
}

/// Stroke cap.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StrokeCap {
    Butt,
    Round,
    Square,
}

/// Stroke join.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StrokeJoin {
    Miter,
    Round,
    Bevel,
}

/// A gradient stop (offset + color).
#[derive(Debug, Clone, PartialEq)]
pub struct GradientStop {
    pub offset: f64,
    pub color: u32,
}

/// Gradient definition.
#[derive(Debug, Clone, PartialEq)]
pub struct ShapeGradient {
    pub gradient_type: GradientType,
    pub stops: Vec<GradientStop>,
    pub start_x: f64,
    pub start_y: f64,
    pub end_x: f64,
    pub end_y: f64,
}

/// A single fill layer.
#[derive(Debug, Clone, PartialEq)]
pub struct ShapeFill {
    pub color: u32,
    pub opacity: f64,
    pub hidden: bool,
    pub gradient: Option<ShapeGradient>,
}

/// A single stroke layer.
#[derive(Debug, Clone, PartialEq)]
pub struct ShapeStroke {
    pub color: u32,
    pub width: f64,
    pub opacity: f64,
    pub hidden: bool,
    pub alignment: StrokeAlignment,
    pub cap: StrokeCap,
    pub join: StrokeJoin,
}

/// Shadow effect.
#[derive(Debug, Clone, PartialEq)]
pub struct ShapeShadow {
    pub style: ShadowStyle,
    pub color: u32,
    pub opacity: f64,
    pub offset_x: f64,
    pub offset_y: f64,
    pub blur: f64,
    pub spread: f64,
    pub hidden: bool,
}

/// Blur effect.
#[derive(Debug, Clone, PartialEq)]
pub struct ShapeBlur {
    pub blur_type: BlurType,
    pub value: f64,
    pub hidden: bool,
}

/// Type-specific geometric data for each shape variant.
#[derive(Debug, Clone, PartialEq)]
pub enum ShapeGeometry {
    Rectangle {
        width: f64,
        height: f64,
        r1: f64,
        r2: f64,
        r3: f64,
        r4: f64,
    },
    Ellipse {
        width: f64,
        height: f64,
    },
    Text {
        width: f64,
        height: f64,
        text: String,
        font_size: f64,
        font_family: String,
        font_weight: u16,
        line_height: f64,
        letter_spacing_percent: f64,
        text_align: TextAlign,
    },
    Frame {
        width: f64,
        height: f64,
        clip_content: bool,
    },
    Group {
        width: f64,
        height: f64,
    },
    Path {
        width: f64,
        height: f64,
        path_data: String,
        closed: bool,
    },
    Image {
        width: f64,
        height: f64,
        asset_id: String,
    },
    Svg {
        width: f64,
        height: f64,
        svg_content: String,
    },
    Bool {
        width: f64,
        height: f64,
        operation: BoolOp,
    },
}

impl ShapeGeometry {
    /// Get the local-space width and height of the geometry.
    pub fn dimensions(&self) -> (f64, f64) {
        match self {
            ShapeGeometry::Rectangle { width, height, .. } => (*width, *height),
            ShapeGeometry::Ellipse { width, height } => (*width, *height),
            ShapeGeometry::Text { width, height, .. } => (*width, *height),
            ShapeGeometry::Frame { width, height, .. } => (*width, *height),
            ShapeGeometry::Group { width, height } => (*width, *height),
            ShapeGeometry::Path { width, height, .. } => (*width, *height),
            ShapeGeometry::Image { width, height, .. } => (*width, *height),
            ShapeGeometry::Svg { width, height, .. } => (*width, *height),
            ShapeGeometry::Bool { width, height, .. } => (*width, *height),
        }
    }
}

/// A render-optimized shape. Mirrors the Dart `Shape` hierarchy but only
/// carries fields needed for rendering and spatial queries.
#[derive(Debug, Clone, PartialEq)]
pub struct RenderShape {
    pub id: String,
    pub shape_type: ShapeType,
    pub transform: Matrix2D,
    pub parent_id: Option<String>,
    pub frame_id: Option<String>,
    pub sort_order: i32,
    pub opacity: f64,
    pub hidden: bool,
    pub rotation: f64,
    pub fills: Vec<ShapeFill>,
    pub strokes: Vec<ShapeStroke>,
    pub shadow: Option<ShapeShadow>,
    pub blur: Option<ShapeBlur>,
    pub geometry: ShapeGeometry,
}

impl RenderShape {
    /// Get the local-space bounding rect as (x, y, w, h).
    /// Position comes from transform (e, f).
    pub fn local_bounds(&self) -> (f64, f64, f64, f64) {
        let (w, h) = self.geometry.dimensions();
        (0.0, 0.0, w, h)
    }

    /// Get the world-space axis-aligned bounding box.
    pub fn world_aabb(&self) -> crate::math::aabb::Aabb {
        let (_, _, w, h) = self.local_bounds();
        let (bx, by, bw, bh) = self.transform.transform_rect(0.0, 0.0, w, h);
        crate::math::aabb::Aabb::from_xywh(bx, by, bw, bh)
    }

    /// Check if this is a container (Group or Frame).
    pub fn is_container(&self) -> bool {
        matches!(self.shape_type, ShapeType::Group | ShapeType::Frame)
    }

    /// Check if this is a frame with clip_content enabled.
    pub fn clips_content(&self) -> bool {
        matches!(self.geometry, ShapeGeometry::Frame { clip_content: true, .. })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_rect_shape(id: &str, x: f64, y: f64, w: f64, h: f64) -> RenderShape {
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
    fn local_bounds_of_rectangle() {
        let s = make_rect_shape("r1", 100.0, 200.0, 50.0, 30.0);
        let (x, y, w, h) = s.local_bounds();
        assert_eq!(x, 0.0);
        assert_eq!(y, 0.0);
        assert_eq!(w, 50.0);
        assert_eq!(h, 30.0);
    }

    #[test]
    fn world_aabb_with_translation() {
        let s = make_rect_shape("r1", 100.0, 200.0, 50.0, 30.0);
        let aabb = s.world_aabb();
        assert_eq!(aabb.min_x, 100.0);
        assert_eq!(aabb.min_y, 200.0);
        assert_eq!(aabb.max_x, 150.0);
        assert_eq!(aabb.max_y, 230.0);
    }

    #[test]
    fn is_container_for_frame() {
        let mut s = make_rect_shape("f1", 0.0, 0.0, 100.0, 100.0);
        s.shape_type = ShapeType::Frame;
        s.geometry = ShapeGeometry::Frame {
            width: 100.0,
            height: 100.0,
            clip_content: true,
        };
        assert!(s.is_container());
        assert!(s.clips_content());
    }

    #[test]
    fn is_not_container_for_rectangle() {
        let s = make_rect_shape("r1", 0.0, 0.0, 100.0, 100.0);
        assert!(!s.is_container());
        assert!(!s.clips_content());
    }

    #[test]
    fn geometry_dimensions() {
        let g = ShapeGeometry::Ellipse {
            width: 80.0,
            height: 60.0,
        };
        assert_eq!(g.dimensions(), (80.0, 60.0));
    }

    #[test]
    fn shape_type_equality() {
        assert_eq!(ShapeType::Rectangle, ShapeType::Rectangle);
        assert_ne!(ShapeType::Rectangle, ShapeType::Ellipse);
    }
}
