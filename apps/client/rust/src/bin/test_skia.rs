use tiny_skia::*;

fn main() {
    let t = Transform::from_row(1.0, 2.0, 3.0, 4.0, 5.0, 6.0);
    println!("sx: {}", t.sx);
    println!("kx: {}", t.kx);
    println!("ky: {}", t.ky);
    println!("sy: {}", t.sy);
}
