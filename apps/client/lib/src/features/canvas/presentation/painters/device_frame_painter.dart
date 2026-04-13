import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:vio_core/vio_core.dart' hide StrokeCap, StrokeJoin;

/// Paints iPhone 16 Pro device frame overlays on top of FrameShapes that have
/// [FrameShape.showDeviceFrame] set to true.
///
/// All drawing uses world-space coordinates; this class applies the view
/// matrix transform internally (matching the _paintFrameLabels pattern in
/// RustCanvasPainter).
class DeviceFramePainter {
  DeviceFramePainter._();

  // ── Reference dimensions (iPhone 16 Pro, 402 × 874 logical pixels) ──────

  static const double _refWidth = 402.0;

  /// Inner screen corner radius at reference size.
  static const double _screenRadius = 49.0;

  /// Bezel stroke width (half extends outside the frame bounds).
  static const double _bezelWidth = 6.0;

  /// Corner radius of the outer bezel RRect.
  static const double _bezelRadius = 55.0;

  // Dynamic Island
  static const double _islandW = 126.0;
  static const double _islandH = 37.0;
  static const double _islandRadius = 18.5;
  static const double _islandTopOffset = 12.0;

  // Status bar items are vertically centered at the Dynamic Island pill's center.
  // = _islandTopOffset + _islandH / 2 = 12 + 18.5 = 30.5 pt
  static const double _statusBarCenterY = 30.5;
  // Clock left-anchored so its text center ≈ 69 pt (middle of the left wing).
  // At 15 pt font weight 600, '00:00' is ≈ 38 pt wide → left edge = 69 - 19 = 50.
  static const double _statusBarLeftX = 50.0;
  // Battery body right edge centered in the right wing (264–402 pt, mid = 333 pt).
  // Cluster is ~66 pt wide → right edge = 333 + 33 = 366 pt = _refWidth - 36.
  static const double _statusBarRightX = _refWidth - 36.0; // = 366

  // Side hardware buttons (outside the bezel, at reference 402 × 874 pt)
  static const double _buttonW = 4.0;
  static const double _buttonRadius = 2.0;
  // Left side (action + volume)
  static const double _actionBtnY = 110.0;
  static const double _actionBtnH = 34.0;
  static const double _volUpY = 160.0;
  static const double _volUpH = 36.0;
  static const double _volDownY = 206.0;
  static const double _volDownH = 36.0;
  // Right side (power)
  static const double _powerBtnY = 160.0;
  static const double _powerBtnH = 78.0;

  // Home indicator
  static const double _homeW = 134.0;
  static const double _homeH = 5.0;
  static const double _homeRadius = 2.5;
  static const double _homeBottomOffset = 8.0;

  // ── Colors ────────────────────────────────────────────────────────────────

  static const Color _bezelColor = Color(0xFF3A3A3C);
  static const Color _islandColor = Colors.black;

  // Light-mode status bar / home indicator
  static const Color _statusColorLight = Color(0xFF000000);
  static const Color _homeColorLight = Color(0xFF000000);

  // Dark-mode status bar / home indicator
  static const Color _statusColorDark = Color(0xFFFFFFFF);
  static const Color _homeColorDark = Color(0xFFFFFFFF);

  // ── Public entry point ───────────────────────────────────────────────────

  /// Paint device frames for all [FrameShape]s in [shapes] that have
  /// [FrameShape.showDeviceFrame] == true.
  ///
  /// [canvas] is the raw Flutter canvas (view matrix NOT yet applied).
  /// [viewMatrix] is the current viewport 2-D transform.
  /// [backgroundColor] is the canvas background color used to mask screen
  /// corners.
  static void paintDeviceFrames(
    Canvas canvas,
    List<Shape> shapes,
    Matrix2D viewMatrix,
    Color backgroundColor,
  ) {
    // Collect frames that want a device overlay.
    final frames = shapes.whereType<FrameShape>().where(
          (f) => f.showDeviceFrame,
        );
    if (frames.isEmpty) return;

    // Apply view transform (world-space drawing).
    canvas.save();
    canvas.transform(
      Float64List.fromList([
        viewMatrix.a,
        viewMatrix.b,
        0,
        0,
        viewMatrix.c,
        viewMatrix.d,
        0,
        0,
        0,
        0,
        1,
        0,
        viewMatrix.e,
        viewMatrix.f,
        0,
        1,
      ]),
    );

    for (final frame in frames) {
      _paintSingleFrame(canvas, frame, backgroundColor);
    }

    canvas.restore();
  }

  // ── Private per-frame renderer ───────────────────────────────────────────

  static void _paintSingleFrame(
    Canvas canvas,
    FrameShape frame,
    Color backgroundColor,
  ) {
    final scale = frame.frameWidth / _refWidth;
    final sx = frame.x;
    final sy = frame.y;
    final fw = frame.frameWidth;
    final fh = frame.frameHeight;
    final darkMode = frame.deviceFrameDarkMode;
    final statusColor = darkMode ? _statusColorDark : _statusColorLight;
    final homeColor = darkMode ? _homeColorDark : _homeColorLight;

    // 1. Rounded corner masks — fill the four corner regions (outside the
    //    inner rounded rect but inside the rectangular frame) with the canvas
    //    background color. This fakes rounded screen corners without altering
    //    the Rust clip path.
    _paintCornerMasks(canvas, sx, sy, fw, fh, scale, backgroundColor);

    // 2. Bezel border — titanium-gradient RRect stroke framing the screen.
    _paintBezel(canvas, sx, sy, fw, fh, scale);

    // 3. Side hardware buttons — drawn outside the bezel bounds.
    _paintSideButtons(canvas, sx, sy, fw, fh, scale);

    // 4. Dynamic Island — black pill at the top center.
    _paintDynamicIsland(canvas, sx, sy, fw, scale);

    // 5. Status bar — clock (left), signal / wifi / battery (right).
    _paintStatusBar(canvas, sx, sy, fw, scale, statusColor);

    // 6. Home indicator — bottom-centered pill.
    _paintHomeIndicator(canvas, sx, sy, fw, fh, scale, homeColor);
  }

  // ── 1. Corner masks ──────────────────────────────────────────────────────

  static void _paintCornerMasks(
    Canvas canvas,
    double sx,
    double sy,
    double fw,
    double fh,
    double scale,
    Color backgroundColor,
  ) {
    final r = _screenRadius * scale;
    final frameRect = Rect.fromLTWH(sx, sy, fw, fh);
    final screenRRect = RRect.fromRectAndRadius(frameRect, Radius.circular(r));

    final cornerPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(frameRect),
      Path()..addRRect(screenRRect),
    );

    canvas.drawPath(
      cornerPath,
      Paint()..color = backgroundColor,
    );
  }

  // ── 2. Bezel border ──────────────────────────────────────────────────────

  static void _paintBezel(
    Canvas canvas,
    double sx,
    double sy,
    double fw,
    double fh,
    double scale,
  ) {
    final bw = _bezelWidth * scale;
    final br = _bezelRadius * scale;

    final bezelRect = Rect.fromLTWH(sx, sy, fw, fh);
    final bezelRRect = RRect.fromRectAndRadius(bezelRect, Radius.circular(br));

    // Brushed-titanium gradient: lighter highlight at top, darker at bottom.
    final gradient = ui.Gradient.linear(
      Offset(sx, sy),
      Offset(sx, sy + fh),
      const [Color(0xFF5A5A5C), Color(0xFF1C1C1E)],
    );

    canvas.drawRRect(
      bezelRRect,
      Paint()
        ..shader = gradient
        ..style = PaintingStyle.stroke
        ..strokeWidth = bw,
    );
  }

  // ── 3. Side hardware buttons ─────────────────────────────────────────────

  static void _paintSideButtons(
    Canvas canvas,
    double sx,
    double sy,
    double fw,
    double fh,
    double scale,
  ) {
    final bw = _buttonW * scale;
    final br = _buttonRadius * scale;
    final paint = Paint()
      ..color = _bezelColor
      ..style = PaintingStyle.fill;

    // Left side: buttons sit just outside the left bezel edge.
    final leftX = sx - bw;
    for (final (btnY, btnH) in [
      (_actionBtnY, _actionBtnH),
      (_volUpY, _volUpH),
      (_volDownY, _volDownH),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(leftX, sy + btnY * scale, bw, btnH * scale),
          Radius.circular(br),
        ),
        paint,
      );
    }

    // Right side: power button just outside the right bezel edge.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(sx + fw, sy + _powerBtnY * scale, bw, _powerBtnH * scale),
        Radius.circular(br),
      ),
      paint,
    );
  }

  // ── 3. Dynamic Island ────────────────────────────────────────────────────

  static void _paintDynamicIsland(
    Canvas canvas,
    double sx,
    double sy,
    double fw,
    double scale,
  ) {
    final iw = _islandW * scale;
    final ih = _islandH * scale;
    final ir = _islandRadius * scale;
    final iy = sy + _islandTopOffset * scale;
    final ix = sx + fw / 2.0 - iw / 2.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(ix, iy, iw, ih),
        Radius.circular(ir),
      ),
      Paint()..color = _islandColor,
    );
  }

  // ── 4. Status bar ────────────────────────────────────────────────────────

  static void _paintStatusBar(
    Canvas canvas,
    double sx,
    double sy,
    double fw,
    double scale,
    Color statusColor,
  ) {
    // Single vertical anchor: center of the icon row.
    final centerY = sy + _statusBarCenterY * scale;

    // -- Clock (left)
    _paintClock(canvas, sx + _statusBarLeftX * scale, centerY, scale, statusColor);

    // Layout (at reference 402pt, bodyRightX = 382):
    //   battery  22pt body, right = bodyRightX (= 382)
    //   gap       6pt          battery left = 360
    //   wifi     visible ±8.2pt, center = 360 - 6 - 8.2 ≈ 346  → offset 36
    //   gap       5pt          wifi left visible ≈ 346 - 8.2 - 0.75 = 337
    //   signal   16.5pt wide   right ≈ 337 - 5 = 332  left = 315.5  → offset 66.5
    final bodyRightX = sx + _statusBarRightX * scale;
    _paintBattery(canvas, bodyRightX, centerY, scale, statusColor);
    _paintWifi(canvas, bodyRightX - 36.0 * scale, centerY, scale, statusColor);
    _paintSignal(canvas, bodyRightX - 66.5 * scale, centerY, scale, statusColor);
  }

  static void _paintClock(
    Canvas canvas,
    double x,
    double centerY,
    double scale,
    Color statusColor,
  ) {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final text = '$hour:$minute';

    final fontSize = 15.0 * scale.clamp(0.6, 3.0);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: statusColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Vertically center text on the shared icon centerY.
    tp.paint(canvas, Offset(x, centerY - tp.height / 2));
  }

  static void _paintBattery(
    Canvas canvas,
    double rightX,
    double centerY,
    double scale,
    Color statusColor,
  ) {
    final bw = 22.0 * scale;
    final bh = 12.0 * scale;
    final capW = 3.0 * scale;
    final capH = 6.0 * scale;
    final strokeW = 1.2 * scale;

    final top = centerY - bh / 2;
    final left = rightX - bw;

    // Outline
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, bw, bh),
        Radius.circular(2.5 * scale),
      ),
      Paint()
        ..color = statusColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW,
    );

    // Cap nub — flush against the right side of the body, centered on centerY
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rightX + strokeW / 2,
          centerY - capH / 2,
          capW,
          capH,
        ),
        Radius.circular(1.0 * scale),
      ),
      Paint()..color = statusColor,
    );

    // Fill (80%)
    final fillW = (bw - strokeW * 4) * 0.80;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          left + strokeW * 2,
          top + strokeW * 2,
          fillW,
          bh - strokeW * 4,
        ),
        Radius.circular(1.5 * scale),
      ),
      Paint()..color = statusColor,
    );
  }

  static void _paintWifi(
    Canvas canvas,
    double centerX,
    double centerY,
    double scale,
    Color statusColor,
  ) {
    // 3 arcs only (no dot). Arc bounding box vertically spans:
    //   top    = arcAnchorY - outerR  = anchorY - 9.5
    //   bottom = arcAnchorY - innerR/2 = anchorY - 1.75  (arc endpoints at 210°/330°)
    // Visual center = anchorY - 5.625 → set anchorY = centerY + 5.625 to align.
    final arcAnchorY = centerY + 5.625 * scale;

    final paint = Paint()
      ..color = statusColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * scale
      ..strokeCap = ui.StrokeCap.round;

    // 3 concentric arcs, 120° sweep centered on the upward direction.
    // startAngle = -150° (-2.618 rad), sweepAngle = 120° (2.094 rad).
    const startAngle = -2.618; // −150°
    const sweepAngle = 2.094;  // 120°
    for (final r in [3.5 * scale, 6.5 * scale, 9.5 * scale]) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(centerX, arcAnchorY),
          width: r * 2,
          height: r * 2,
        ),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }

    // Dot at the geometric origin of the concentric arc system — the WiFi
    // bullseye point. The innermost arc endpoint sits at arcAnchorY - 1.75*scale
    // (210°/330°), so drawing at arcAnchorY leaves a natural ~1.75 pt gap.
    final dotR = 1.5 * scale;
    canvas.drawCircle(
      Offset(centerX, arcAnchorY),
      dotR,
      Paint()
        ..color = statusColor
        ..style = PaintingStyle.fill,
    );
  }

  static void _paintSignal(
    Canvas canvas,
    double leftX,
    double centerY,
    double scale,
    Color statusColor,
  ) {
    final paint = Paint()
      ..color = statusColor
      ..style = PaintingStyle.fill;

    const barCount = 4;
    final barW = 3.0 * scale;
    final barGap = 1.5 * scale;
    final maxH = 12.0 * scale;
    // Bars are bottom-aligned at the icon bottom edge.
    final barBottomY = centerY + maxH / 2;

    for (var i = 0; i < barCount; i++) {
      final barH = maxH * (i + 1) / barCount;
      final bx = leftX + i * (barW + barGap);
      final by = barBottomY - barH;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, by, barW, barH),
          Radius.circular(1.0 * scale),
        ),
        paint,
      );
    }
  }

  // ── 5. Home indicator ────────────────────────────────────────────────────

  static void _paintHomeIndicator(
    Canvas canvas,
    double sx,
    double sy,
    double fw,
    double fh,
    double scale,
    Color homeColor,
  ) {
    final hw = _homeW * scale;
    final hh = _homeH * scale;
    final hr = _homeRadius * scale;
    final hx = sx + fw / 2.0 - hw / 2.0;
    final hy = sy + fh - _homeBottomOffset * scale - hh;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(hx, hy, hw, hh),
        Radius.circular(hr),
      ),
      Paint()..color = homeColor,
    );
  }
}
