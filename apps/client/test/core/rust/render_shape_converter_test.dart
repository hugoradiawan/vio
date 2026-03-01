import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:vio_client/src/core/rust/render_shape_converter.dart';
import 'package:vio_client/src/rust/scene_graph/shape.dart' as frb;
import 'package:vio_core/vio_core.dart';

void main() {
  // ─── Helper factories ──────────────────────────────────────────────
  RectangleShape rect0({
    String id = 'r1',
    double width = 100,
    double height = 50,
    double x = 10,
    double y = 20,
    Matrix2D transform = Matrix2D.identity,
    List<ShapeFill> fills = const [],
    List<ShapeStroke> strokes = const [],
    double opacity = 1.0,
    bool hidden = false,
    double rotation = 0.0,
    int sortOrder = 0,
    ShapeShadow? shadow,
    ShapeBlur? blur,
    String? parentId,
    String? frameId,
    double r1 = 0,
    double r2 = 0,
    double r3 = 0,
    double r4 = 0,
  }) =>
      RectangleShape(
        id: id,
        name: 'Rect',
        x: x,
        y: y,
        rectWidth: width,
        rectHeight: height,
        transform: transform,
        fills: fills,
        strokes: strokes,
        opacity: opacity,
        hidden: hidden,
        rotation: rotation,
        sortOrder: sortOrder,
        shadow: shadow,
        blur: blur,
        parentId: parentId,
        frameId: frameId,
        r1: r1,
        r2: r2,
        r3: r3,
        r4: r4,
      );

  // ─── toRenderShape ─────────────────────────────────────────────────
  group('toRenderShape', () {
    group('base fields', () {
      test('converts id, transform, sortOrder, opacity, hidden, rotation', () {
        final shape = rect0(
          id: 'abc',
          transform: const Matrix2D(a: 2, b: 0, c: 0, d: 2, e: 30, f: 40),
          sortOrder: 5,
          opacity: 0.8,
          hidden: true,
          rotation: 45.0,
        );
        final rs = RenderShapeConverter.toRenderShape(shape);

        expect(rs.id, 'abc');
        expect(rs.shapeType, frb.ShapeType.rectangle);
        expect(rs.transform.a, 2.0);
        // transform.e/f now includes the baked-in x/y offset:
        // e' = a*x + c*y + e = 2*10 + 0*20 + 30 = 50
        // f' = b*x + d*y + f = 0*10 + 2*20 + 40 = 80
        expect(rs.transform.e, 50.0);
        expect(rs.transform.f, 80.0);
        expect(rs.sortOrder, 5);
        expect(rs.opacity, 0.8);
        expect(rs.hidden, true);
        expect(rs.rotation, 45.0);
      });

      test('converts parentId and frameId', () {
        final shape = rect0(parentId: 'p1', frameId: 'f1');
        final rs = RenderShapeConverter.toRenderShape(shape);

        expect(rs.parentId, 'p1');
        expect(rs.frameId, 'f1');
      });

      test('null parentId and frameId', () {
        final shape = rect0();
        final rs = RenderShapeConverter.toRenderShape(shape);

        expect(rs.parentId, isNull);
        expect(rs.frameId, isNull);
      });
    });

    // ─── Fills ───────────────────────────────────────────────────────
    group('fills', () {
      test('converts basic fill', () {
        final shape = rect0(
          fills: [const ShapeFill(color: 0xFF4C9AFF, opacity: 0.9)],
        );
        final rs = RenderShapeConverter.toRenderShape(shape);

        expect(rs.fills.length, 1);
        expect(rs.fills[0].color, 0xFF4C9AFF);
        expect(rs.fills[0].opacity, 0.9);
        expect(rs.fills[0].hidden, false);
        expect(rs.fills[0].gradient, isNull);
      });

      test('converts fill with gradient', () {
        final shape = rect0(
          fills: [
            const ShapeFill(
              color: 0xFF000000,
              gradient: ShapeGradient(
                type: GradientType.linear,
                stops: [
                  GradientStop(color: 0xFFFF0000, offset: 0.0, opacity: 0.5),
                  GradientStop(color: 0xFF0000FF, offset: 1.0),
                ],
                startX: 0.1,
                startY: 0.2,
                endX: 0.9,
                endY: 0.8,
              ),
            ),
          ],
        );
        final rs = RenderShapeConverter.toRenderShape(shape);
        final grad = rs.fills[0].gradient!;

        expect(grad.gradientType, frb.GradientType.linear);
        expect(grad.stops.length, 2);
        expect(grad.startX, 0.1);
        expect(grad.startY, 0.2);
        expect(grad.endX, 0.9);
        expect(grad.endY, 0.8);
      });

      test('bakes gradient stop opacity into alpha channel', () {
        final shape = rect0(
          fills: [
            const ShapeFill(
              color: 0xFF000000,
              gradient: ShapeGradient(
                type: GradientType.linear,
                stops: [
                  // Fully opaque red with 50% opacity → alpha should be ~128
                  GradientStop(color: 0xFFFF0000, offset: 0.0, opacity: 0.5),
                  // Fully opaque blue, default opacity 1.0 → stay 0xFF
                  GradientStop(color: 0xFF0000FF, offset: 1.0),
                ],
              ),
            ),
          ],
        );
        final rs = RenderShapeConverter.toRenderShape(shape);
        final stops = rs.fills[0].gradient!.stops;

        // 0xFF * 0.5 = 127.5 → rounds to 128 = 0x80
        expect(stops[0].color, 0x80FF0000);
        expect(stops[1].color, 0xFF0000FF);
      });

      test('hidden fill', () {
        final shape = rect0(
          fills: [const ShapeFill(color: 0xFF000000, hidden: true)],
        );
        final rs = RenderShapeConverter.toRenderShape(shape);

        expect(rs.fills[0].hidden, true);
      });

      test('multiple fills', () {
        final shape = rect0(
          fills: [
            const ShapeFill(color: 0xFFFF0000),
            const ShapeFill(color: 0xFF00FF00, opacity: 0.5),
          ],
        );
        final rs = RenderShapeConverter.toRenderShape(shape);

        expect(rs.fills.length, 2);
        expect(rs.fills[0].color, 0xFFFF0000);
        expect(rs.fills[1].color, 0xFF00FF00);
        expect(rs.fills[1].opacity, 0.5);
      });

      test('empty fills list', () {
        final shape = rect0();
        final rs = RenderShapeConverter.toRenderShape(shape);

        expect(rs.fills, isEmpty);
      });
    });

    // ─── Strokes ─────────────────────────────────────────────────────
    group('strokes', () {
      test('converts stroke with all properties', () {
        final shape = rect0(
          strokes: [
            const ShapeStroke(
              color: 0xFF333333,
              width: 2.5,
              opacity: 0.7,
              hidden: true,
              alignment: StrokeAlignment.inside,
              cap: StrokeCap.square,
              join: StrokeJoin.bevel,
            ),
          ],
        );
        final rs = RenderShapeConverter.toRenderShape(shape);
        final s = rs.strokes[0];

        expect(s.color, 0xFF333333);
        expect(s.width, 2.5);
        expect(s.opacity, 0.7);
        expect(s.hidden, true);
        expect(s.alignment, frb.StrokeAlignment.inside);
        expect(s.cap, frb.StrokeCap.square);
        expect(s.join, frb.StrokeJoin.bevel);
      });

      test('converts default stroke values', () {
        final shape = rect0(
          strokes: [const ShapeStroke(color: 0xFF000000)],
        );
        final rs = RenderShapeConverter.toRenderShape(shape);
        final s = rs.strokes[0];

        expect(s.width, 1.0);
        expect(s.opacity, 1.0);
        expect(s.hidden, false);
        expect(s.alignment, frb.StrokeAlignment.center);
        expect(s.cap, frb.StrokeCap.round);
        expect(s.join, frb.StrokeJoin.round);
      });
    });

    // ─── Shadow ──────────────────────────────────────────────────────
    group('shadow', () {
      test('null shadow', () {
        final shape = rect0();
        final rs = RenderShapeConverter.toRenderShape(shape);

        expect(rs.shadow, isNull);
      });

      test('converts drop shadow (name maps to drop)', () {
        final shape = rect0(
          shadow: const ShapeShadow(
            color: 0xFF000000,
            opacity: 0.3,
            offsetX: 5.0,
            offsetY: 10.0,
            blur: 15.0,
            spread: 2.0,
          ),
        );
        final rs = RenderShapeConverter.toRenderShape(shape);
        final sh = rs.shadow!;

        expect(sh.style, frb.ShadowStyle.drop);
        expect(sh.color, 0xFF000000);
        expect(sh.opacity, 0.3);
        expect(sh.offsetX, 5.0);
        expect(sh.offsetY, 10.0);
        expect(sh.blur, 15.0);
        expect(sh.spread, 2.0);
        expect(sh.hidden, false);
      });

      test('converts inner shadow (name maps to inner)', () {
        final shape = rect0(
          shadow: const ShapeShadow(style: ShadowStyle.innerShadow),
        );
        final rs = RenderShapeConverter.toRenderShape(shape);

        expect(rs.shadow!.style, frb.ShadowStyle.inner);
      });
    });

    // ─── Blur ────────────────────────────────────────────────────────
    group('blur', () {
      test('null blur', () {
        final shape = rect0();
        final rs = RenderShapeConverter.toRenderShape(shape);

        expect(rs.blur, isNull);
      });

      test('converts layer blur (field name: type → blurType)', () {
        final shape = rect0(
          blur: const ShapeBlur(value: 4.5, hidden: true),
        );
        final rs = RenderShapeConverter.toRenderShape(shape);
        final b = rs.blur!;

        expect(b.blurType, frb.BlurType.layer);
        expect(b.value, 4.5);
        expect(b.hidden, true);
      });

      test('converts background blur', () {
        final shape = rect0(
          blur: const ShapeBlur(type: BlurType.background, value: 10.0),
        );
        final rs = RenderShapeConverter.toRenderShape(shape);

        expect(rs.blur!.blurType, frb.BlurType.background);
      });
    });

    // ─── Geometry: Rectangle ─────────────────────────────────────────
    group('geometry: rectangle', () {
      test('converts dimensions and corner radii', () {
        final shape = rect0(
          width: 200,
          height: 100,
          r1: 4,
          r2: 8,
          r3: 12,
          r4: 16,
        );
        final rs = RenderShapeConverter.toRenderShape(shape);
        final geom = rs.geometry;

        expect(geom, isA<frb.ShapeGeometry_Rectangle>());
        final rect = geom as frb.ShapeGeometry_Rectangle;
        expect(rect.width, 200.0);
        expect(rect.height, 100.0);
        expect(rect.r1, 4.0);
        expect(rect.r2, 8.0);
        expect(rect.r3, 12.0);
        expect(rect.r4, 16.0);
      });
    });

    // ─── Geometry: Ellipse ───────────────────────────────────────────
    group('geometry: ellipse', () {
      test('converts dimensions', () {
        const shape = EllipseShape(
          id: 'e1',
          name: 'Ellipse',
          x: 0,
          y: 0,
          ellipseWidth: 120,
          ellipseHeight: 80,
        );
        final rs = RenderShapeConverter.toRenderShape(shape);

        expect(rs.shapeType, frb.ShapeType.ellipse);
        final geom = rs.geometry as frb.ShapeGeometry_Ellipse;
        expect(geom.width, 120.0);
        expect(geom.height, 80.0);
      });
    });

    // ─── Geometry: Text ──────────────────────────────────────────────
    group('geometry: text', () {
      test('converts text properties', () {
        const shape = TextShape(
          id: 't1',
          name: 'Text',
          x: 0,
          y: 0,
          textWidth: 300,
          textHeight: 40,
          text: 'Hello World',
          fontSize: 24.0,
          fontFamily: 'Roboto',
          fontWeight: 700,
          lineHeight: 1.5,
          letterSpacingPercent: 2.0,
          textAlign: ui.TextAlign.center,
        );
        final rs = RenderShapeConverter.toRenderShape(shape);

        expect(rs.shapeType, frb.ShapeType.text);
        final geom = rs.geometry as frb.ShapeGeometry_Text;
        expect(geom.width, 300.0);
        expect(geom.height, 40.0);
        expect(geom.text, 'Hello World');
        expect(geom.fontSize, 24.0);
        expect(geom.fontFamily, 'Roboto');
        expect(geom.fontWeight, 700);
        expect(geom.lineHeight, 1.5);
        expect(geom.letterSpacingPercent, 2.0);
        expect(geom.textAlign, frb.TextAlign.center);
      });

      test('null fontFamily defaults to Inter', () {
        const shape = TextShape(
          id: 't2',
          name: 'Text',
          x: 0,
          y: 0,
          textWidth: 100,
          textHeight: 20,
          text: 'Test',
        );
        final rs = RenderShapeConverter.toRenderShape(shape);
        final geom = rs.geometry as frb.ShapeGeometry_Text;

        expect(geom.fontFamily, 'Inter');
      });

      test('null fontWeight defaults to 400', () {
        const shape = TextShape(
          id: 't3',
          name: 'Text',
          x: 0,
          y: 0,
          textWidth: 100,
          textHeight: 20,
          text: 'Test',
        );
        final rs = RenderShapeConverter.toRenderShape(shape);
        final geom = rs.geometry as frb.ShapeGeometry_Text;

        expect(geom.fontWeight, 400);
      });

      test('null lineHeight defaults to 1.2', () {
        const shape = TextShape(
          id: 't4',
          name: 'Text',
          x: 0,
          y: 0,
          textWidth: 100,
          textHeight: 20,
          text: 'Test',
        );
        final rs = RenderShapeConverter.toRenderShape(shape);
        final geom = rs.geometry as frb.ShapeGeometry_Text;

        expect(geom.lineHeight, 1.2);
      });

      test('TextAlign.start maps to left', () {
        const shape = TextShape(
          id: 't5',
          name: 'Text',
          x: 0,
          y: 0,
          textWidth: 100,
          textHeight: 20,
          text: 'Test',
          textAlign: ui.TextAlign.start,
        );
        final rs = RenderShapeConverter.toRenderShape(shape);
        final geom = rs.geometry as frb.ShapeGeometry_Text;

        expect(geom.textAlign, frb.TextAlign.left);
      });

      test('TextAlign.end maps to right', () {
        const shape = TextShape(
          id: 't6',
          name: 'Text',
          x: 0,
          y: 0,
          textWidth: 100,
          textHeight: 20,
          text: 'Test',
          textAlign: ui.TextAlign.end,
        );
        final rs = RenderShapeConverter.toRenderShape(shape);
        final geom = rs.geometry as frb.ShapeGeometry_Text;

        expect(geom.textAlign, frb.TextAlign.right);
      });

      test('TextAlign.justify maps correctly', () {
        const shape = TextShape(
          id: 't7',
          name: 'Text',
          x: 0,
          y: 0,
          textWidth: 100,
          textHeight: 20,
          text: 'Test',
          textAlign: ui.TextAlign.justify,
        );
        final rs = RenderShapeConverter.toRenderShape(shape);
        final geom = rs.geometry as frb.ShapeGeometry_Text;

        expect(geom.textAlign, frb.TextAlign.justify);
      });
    });

    // ─── Geometry: Frame ─────────────────────────────────────────────
    group('geometry: frame', () {
      test('converts dimensions and clipContent', () {
        const shape = FrameShape(
          id: 'f1',
          name: 'Frame',
          x: 0,
          y: 0,
          frameWidth: 800,
          frameHeight: 600,
          clipContent: false,
        );
        final rs = RenderShapeConverter.toRenderShape(shape);

        expect(rs.shapeType, frb.ShapeType.frame);
        final geom = rs.geometry as frb.ShapeGeometry_Frame;
        expect(geom.width, 800.0);
        expect(geom.height, 600.0);
        expect(geom.clipContent, false);
      });
    });

    // ─── Geometry: Group ─────────────────────────────────────────────
    group('geometry: group', () {
      test('converts dimensions', () {
        const shape = GroupShape(
          id: 'g1',
          name: 'Group',
          x: 0,
          y: 0,
          groupWidth: 400,
          groupHeight: 300,
        );
        final rs = RenderShapeConverter.toRenderShape(shape);

        expect(rs.shapeType, frb.ShapeType.group);
        final geom = rs.geometry as frb.ShapeGeometry_Group;
        expect(geom.width, 400.0);
        expect(geom.height, 300.0);
      });
    });

    // ─── Geometry: Path ──────────────────────────────────────────────
    group('geometry: path', () {
      test('converts path data and closed flag', () {
        const shape = PathShape(
          id: 'p1',
          name: 'Path',
          x: 0,
          y: 0,
          pathWidth: 50,
          pathHeight: 50,
          pathData: 'M0 0 L50 50',
          closed: true,
        );
        final rs = RenderShapeConverter.toRenderShape(shape);

        expect(rs.shapeType, frb.ShapeType.path);
        final geom = rs.geometry as frb.ShapeGeometry_Path;
        expect(geom.width, 50.0);
        expect(geom.height, 50.0);
        expect(geom.pathData, 'M0 0 L50 50');
        expect(geom.closed, true);
      });
    });

    // ─── Geometry: Image ─────────────────────────────────────────────
    group('geometry: image', () {
      test('converts dimensions and assetId', () {
        const shape = ImageShape(
          id: 'i1',
          name: 'Image',
          x: 0,
          y: 0,
          imageWidth: 640,
          imageHeight: 480,
          assetId: 'asset-uuid-123',
        );
        final rs = RenderShapeConverter.toRenderShape(shape);

        expect(rs.shapeType, frb.ShapeType.image);
        final geom = rs.geometry as frb.ShapeGeometry_Image;
        expect(geom.width, 640.0);
        expect(geom.height, 480.0);
        expect(geom.assetId, 'asset-uuid-123');
      });
    });

    // ─── Geometry: SVG ───────────────────────────────────────────────
    group('geometry: svg', () {
      test('converts dimensions and svgContent', () {
        const shape = SvgShape(
          id: 's1',
          name: 'SVG',
          x: 0,
          y: 0,
          svgWidth: 24,
          svgHeight: 24,
          svgContent: '<svg>...</svg>',
        );
        final rs = RenderShapeConverter.toRenderShape(shape);

        expect(rs.shapeType, frb.ShapeType.svg);
        final geom = rs.geometry as frb.ShapeGeometry_Svg;
        expect(geom.width, 24.0);
        expect(geom.height, 24.0);
        expect(geom.svgContent, '<svg>...</svg>');
      });
    });

    // ─── Geometry: Bool ──────────────────────────────────────────────
    group('geometry: bool', () {
      test('converts dimensions and all BoolOperation variants', () {
        for (final op in BoolOperation.values) {
          final shape = BoolShape(
            id: 'b-${op.name}',
            name: 'Bool',
            x: 0,
            y: 0,
            boolWidth: 100,
            boolHeight: 100,
            operation: op,
          );
          final rs = RenderShapeConverter.toRenderShape(shape);

          expect(rs.shapeType, frb.ShapeType.bool);
          final geom = rs.geometry as frb.ShapeGeometry_Bool;
          expect(geom.width, 100.0);
          expect(geom.height, 100.0);

          final expectedOp = switch (op) {
            BoolOperation.union => frb.BoolOp.union,
            BoolOperation.subtract => frb.BoolOp.subtract,
            BoolOperation.intersect => frb.BoolOp.intersect,
            BoolOperation.exclude => frb.BoolOp.exclude,
          };
          expect(geom.operation, expectedOp);
        }
      });
    });
  });

  // ─── toRenderShapes (batch) ────────────────────────────────────────
  group('toRenderShapes', () {
    test('converts a map of shapes', () {
      final shapes = {
        'r1': rect0(),
        'r2': rect0(id: 'r2', width: 200),
      };
      final list = RenderShapeConverter.toRenderShapes(shapes);

      expect(list.length, 2);
      expect(list.map((r) => r.id).toSet(), {'r1', 'r2'});
    });

    test('empty map returns empty list', () {
      final list = RenderShapeConverter.toRenderShapes({});

      expect(list, isEmpty);
    });
  });

  // ─── diffShapes ────────────────────────────────────────────────────
  group('diffShapes', () {
    test('all new shapes appear as added', () {
      final newShapes = {'r1': rect0(), 'r2': rect0(id: 'r2')};
      final diff = RenderShapeConverter.diffShapes({}, newShapes);

      expect(diff.added.length, 2);
      expect(diff.updated, isEmpty);
      expect(diff.removed, isEmpty);
    });

    test('all old shapes missing from new appear as removed', () {
      final oldShapes = {'r1': rect0(), 'r2': rect0(id: 'r2')};
      final diff = RenderShapeConverter.diffShapes(oldShapes, {});

      expect(diff.added, isEmpty);
      expect(diff.updated, isEmpty);
      expect(diff.removed.length, 2);
      expect(diff.removed.toSet(), {'r1', 'r2'});
    });

    test('unchanged shapes produce no diff', () {
      final shape = rect0();
      final diff = RenderShapeConverter.diffShapes(
        {'r1': shape},
        {'r1': shape},
      );

      expect(diff.added, isEmpty);
      expect(diff.updated, isEmpty);
      expect(diff.removed, isEmpty);
    });

    test('modified shape appears as updated', () {
      final old = rect0();
      final modified = rect0(width: 200);
      final diff = RenderShapeConverter.diffShapes(
        {'r1': old},
        {'r1': modified},
      );

      expect(diff.added, isEmpty);
      expect(diff.updated.length, 1);
      expect(diff.updated[0].id, 'r1');
      expect(diff.removed, isEmpty);
    });

    test('mixed add/update/remove', () {
      final kept = rect0(id: 'kept');
      final modified = rect0(id: 'mod');
      final modifiedNew = rect0(id: 'mod', width: 200);
      final removed = rect0(id: 'del');
      final added = rect0(id: 'new');

      final oldShapes = {'kept': kept, 'mod': modified, 'del': removed};
      final newShapes = {'kept': kept, 'mod': modifiedNew, 'new': added};

      final diff = RenderShapeConverter.diffShapes(oldShapes, newShapes);

      expect(diff.added.length, 1);
      expect(diff.added[0].id, 'new');
      expect(diff.updated.length, 1);
      expect(diff.updated[0].id, 'mod');
      expect(diff.removed, ['del']);
    });

    test('both empty maps produce no diff', () {
      final diff = RenderShapeConverter.diffShapes({}, {});

      expect(diff.added, isEmpty);
      expect(diff.updated, isEmpty);
      expect(diff.removed, isEmpty);
    });
  });

  // ─── Enum mapping completeness ─────────────────────────────────────
  group('enum mapping completeness', () {
    test('all StrokeAlignment variants map correctly', () {
      for (final v in StrokeAlignment.values) {
        final shape = rect0(
          strokes: [ShapeStroke(color: 0xFF000000, alignment: v)],
        );
        // Should not throw
        final rs = RenderShapeConverter.toRenderShape(shape);
        expect(rs.strokes[0].alignment, isNotNull);
      }
    });

    test('all StrokeCap variants map correctly', () {
      for (final v in StrokeCap.values) {
        final shape = rect0(
          strokes: [ShapeStroke(color: 0xFF000000, cap: v)],
        );
        final rs = RenderShapeConverter.toRenderShape(shape);
        expect(rs.strokes[0].cap, isNotNull);
      }
    });

    test('all StrokeJoin variants map correctly', () {
      for (final v in StrokeJoin.values) {
        final shape = rect0(
          strokes: [ShapeStroke(color: 0xFF000000, join: v)],
        );
        final rs = RenderShapeConverter.toRenderShape(shape);
        expect(rs.strokes[0].join, isNotNull);
      }
    });

    test('all ShadowStyle variants map correctly', () {
      for (final v in ShadowStyle.values) {
        final shape = rect0(shadow: ShapeShadow(style: v));
        final rs = RenderShapeConverter.toRenderShape(shape);
        expect(rs.shadow!.style, isNotNull);
      }
    });

    test('all BlurType variants map correctly', () {
      for (final v in BlurType.values) {
        final shape = rect0(blur: ShapeBlur(type: v));
        final rs = RenderShapeConverter.toRenderShape(shape);
        expect(rs.blur!.blurType, isNotNull);
      }
    });

    test('all GradientType variants map correctly', () {
      for (final v in GradientType.values) {
        final shape = rect0(
          fills: [
            ShapeFill(
              color: 0xFF000000,
              gradient: ShapeGradient(
                type: v,
                stops: const [
                  GradientStop(color: 0xFF000000, offset: 0),
                  GradientStop(color: 0xFFFFFFFF, offset: 1),
                ],
              ),
            ),
          ],
        );
        final rs = RenderShapeConverter.toRenderShape(shape);
        expect(rs.fills[0].gradient!.gradientType, isNotNull);
      }
    });

    test('all ShapeType variants map correctly', () {
      for (final v in ShapeType.values) {
        // Just test the enum conversion doesn't throw
        final shapes = <Shape>[
          const RectangleShape(
            id: 'r', name: 'R', x: 0, y: 0, rectWidth: 1, rectHeight: 1,
          ),
          const EllipseShape(
            id: 'e', name: 'E', x: 0, y: 0, ellipseWidth: 1, ellipseHeight: 1,
          ),
          const TextShape(
            id: 't', name: 'T', x: 0, y: 0, textWidth: 1, textHeight: 1,
            text: '',
          ),
          const FrameShape(
            id: 'f', name: 'F', x: 0, y: 0, frameWidth: 1, frameHeight: 1,
          ),
          const GroupShape(
            id: 'g', name: 'G', x: 0, y: 0, groupWidth: 1, groupHeight: 1,
          ),
          const PathShape(
            id: 'p', name: 'P', x: 0, y: 0, pathWidth: 1, pathHeight: 1,
          ),
          const ImageShape(
            id: 'i', name: 'I', x: 0, y: 0, imageWidth: 1, imageHeight: 1,
          ),
          const SvgShape(
            id: 's', name: 'S', x: 0, y: 0, svgWidth: 1, svgHeight: 1,
          ),
          const BoolShape(
            id: 'b', name: 'B', x: 0, y: 0, boolWidth: 1, boolHeight: 1,
          ),
        ];
        final match = shapes.where((s) => s.type == v);
        expect(match, isNotEmpty, reason: 'Missing shape for type $v');
        final rs = RenderShapeConverter.toRenderShape(match.first);
        expect(rs.shapeType, isNotNull);
      }
    });
  });

  // ─── Gradient opacity edge cases ───────────────────────────────────
  group('gradient stop opacity edge cases', () {
    test('zero opacity produces zero alpha', () {
      final shape = rect0(
        fills: [
          const ShapeFill(
            color: 0xFF000000,
            gradient: ShapeGradient(
              type: GradientType.linear,
              stops: [
                GradientStop(color: 0xFFFF0000, offset: 0.0, opacity: 0.0),
              ],
            ),
          ),
        ],
      );
      final rs = RenderShapeConverter.toRenderShape(shape);
      final stop = rs.fills[0].gradient!.stops[0];

      expect(stop.color & 0xFF000000, 0x00000000);
    });

    test('half-transparent source with half opacity', () {
      // Source alpha = 0x80 (128), opacity = 0.5 → 128 * 0.5 = 64 = 0x40
      final shape = rect0(
        fills: [
          const ShapeFill(
            color: 0xFF000000,
            gradient: ShapeGradient(
              type: GradientType.linear,
              stops: [
                GradientStop(color: 0x80FF0000, offset: 0.0, opacity: 0.5),
              ],
            ),
          ),
        ],
      );
      final rs = RenderShapeConverter.toRenderShape(shape);
      final stop = rs.fills[0].gradient!.stops[0];

      expect((stop.color >> 24) & 0xFF, 64);
      expect(stop.color & 0x00FFFFFF, 0x00FF0000);
    });
  });
}
