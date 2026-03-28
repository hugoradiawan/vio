use tiny_skia::*;

fn main() {
    let mut pixmap = Pixmap::new(200, 200).unwrap();
    let mut paint = Paint::default();
    paint.set_color_rgba8(255, 0, 0, 255); // Red

    // m_rust = [0, -1, 160; 1, 0, 60]
    let m_rust = Transform::from_row(0.0, 1.0, -1.0, 0.0, 160.0, 60.0);

    let rect = Rect::from_xywh(0.0, 0.0, 100.0, 100.0).unwrap();
    let path = PathBuilder::from_rect(rect);

    pixmap.fill_path(&path, &paint, FillRule::Winding, m_rust, None);

    let mut min_x = 200;
    let mut min_y = 200;
    let mut max_x = 0;
    let mut max_y = 0;

    for y in 0..200 {
        for x in 0..200 {
            let pixel = pixmap.pixel(x, y).unwrap();
            if pixel.red() > 0 {
                min_x = min_x.min(x);
                min_y = min_y.min(y);
                max_x = max_x.max(x);
                max_y = max_y.max(y);
            }
        }
    }

    println!("bbox: {}, {}, {}, {}", min_x, min_y, max_x, max_y);
}
