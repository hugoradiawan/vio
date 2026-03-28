use tiny_skia::Transform;
fn main() {
    let t = Transform::from_row(1.0, 2.0, 3.0, 4.0, 5.0, 6.0);
    println!("sx: {}", t.sx);
    println!("ky: {}", t.ky);
    println!("kx: {}", t.kx);
    println!("sy: {}", t.sy);
    println!("tx: {}", t.tx);
    println!("ty: {}", t.ty);
}
