/**
 * Seed script to create demo project with test shapes
 * Run with: bun run db:seed
 */

import { db, schema } from './index';

// Fixed UUIDs for demo (makes it easy to reference in Flutter app)
const DEMO_PROJECT_ID = '00000000-0000-0000-0000-000000000001';
const DEMO_BRANCH_ID = '00000000-0000-0000-0000-000000000002';
const DEMO_USER_ID = '00000000-0000-0000-0000-000000000099';
const DEMO_FRAME_ID = '00000000-0000-0000-0000-000000000010';

// Shape UUIDs (stable for easy Flutter integration)
const SHAPE_FRAME_ID = '00000000-0000-0000-0001-000000000001';
const SHAPE_RECT_1_ID = '00000000-0000-0000-0001-000000000002';
const SHAPE_RECT_2_ID = '00000000-0000-0000-0001-000000000003';
const SHAPE_ELLIPSE_1_ID = '00000000-0000-0000-0001-000000000004';
const SHAPE_RECT_3_ID = '00000000-0000-0000-0001-000000000005';
const SHAPE_ELLIPSE_2_ID = '00000000-0000-0000-0001-000000000006';

async function seed() {
  console.log('🌱 Starting database seed...');

  try {
    // Clean up existing demo data first
    console.log('🧹 Cleaning up existing demo data...');
    await db.delete(schema.shapes).where(
      // @ts-ignore - eq import issue
      (await import('drizzle-orm')).eq(schema.shapes.projectId, DEMO_PROJECT_ID)
    );
    await db.delete(schema.frames).where(
      (await import('drizzle-orm')).eq(schema.frames.projectId, DEMO_PROJECT_ID)
    );
    await db.delete(schema.branches).where(
      (await import('drizzle-orm')).eq(schema.branches.projectId, DEMO_PROJECT_ID)
    );
    await db.delete(schema.projects).where(
      (await import('drizzle-orm')).eq(schema.projects.id, DEMO_PROJECT_ID)
    );

    // Create demo project
    console.log('📁 Creating demo project...');
    await db.insert(schema.projects).values({
      id: DEMO_PROJECT_ID,
      name: 'Demo Project',
      description: 'A demo project with test shapes for API testing',
      ownerId: DEMO_USER_ID,
      isPublic: true,
      defaultBranchId: DEMO_BRANCH_ID,
    });

    // Create main branch
    console.log('🌿 Creating main branch...');
    await db.insert(schema.branches).values({
      id: DEMO_BRANCH_ID,
      projectId: DEMO_PROJECT_ID,
      name: 'main',
      description: 'Main branch',
      isDefault: true,
      createdById: DEMO_USER_ID,
    });

    // Create frame (artboard)
    console.log('🖼️ Creating frame...');
    await db.insert(schema.frames).values({
      id: DEMO_FRAME_ID,
      projectId: DEMO_PROJECT_ID,
      name: 'Frame 1',
      x: 0,
      y: 0,
      width: 800,
      height: 600,
      backgroundColor: '#2D2D2D',
    });

    // Create shapes matching _createTestShapes() in canvas_bloc.dart
    console.log('🔷 Creating shapes...');

    const shapesData = [
      // Frame as a shape entry (for Flutter compatibility)
      {
        id: SHAPE_FRAME_ID,
        projectId: DEMO_PROJECT_ID,
        frameId: null, // Top-level frame has no parent frame
        type: 'frame',
        name: 'Frame 1',
        x: 0,
        y: 0,
        width: 800,
        height: 600,
        fills: [{ color: 0xFF2D2D2D }],
        strokes: [{ color: 0xFF404040 }],
        properties: {},
      },
      // Blue rectangle - frameId references the frame shape, not frames table
      {
        id: SHAPE_RECT_1_ID,
        projectId: DEMO_PROJECT_ID,
        frameId: null, // Set to null since DB expects frames table reference
        parentShapeId: SHAPE_FRAME_ID, // This is what Flutter actually uses
        type: 'rectangle',
        name: 'Rectangle 1',
        x: 50,
        y: 50,
        width: 200,
        height: 150,
        fills: [{ color: 0xFF3B82F6 }],
        strokes: [{ color: 0xFF1D4ED8, width: 2 }],
        properties: { r1: 8, r2: 8, r3: 8, r4: 8, frameId: SHAPE_FRAME_ID },
      },
      // Green rectangle
      {
        id: SHAPE_RECT_2_ID,
        projectId: DEMO_PROJECT_ID,
        frameId: null,
        type: 'rectangle',
        name: 'Rectangle 2',
        x: 300,
        y: 100,
        width: 180,
        height: 120,
        fills: [{ color: 0xFF22C55E }],
        strokes: [{ color: 0xFF16A34A, width: 2 }],
        properties: { frameId: SHAPE_FRAME_ID },
      },
      // Red ellipse
      {
        id: SHAPE_ELLIPSE_1_ID,
        projectId: DEMO_PROJECT_ID,
        frameId: null,
        type: 'ellipse',
        name: 'Ellipse 1',
        x: 520,
        y: 140,
        width: 160,
        height: 120,
        fills: [{ color: 0xFFEF4444 }],
        strokes: [{ color: 0xFFDC2626, width: 2 }],
        properties: { frameId: SHAPE_FRAME_ID },
      },
      // Yellow rectangle (stroke only)
      {
        id: SHAPE_RECT_3_ID,
        projectId: DEMO_PROJECT_ID,
        frameId: null,
        type: 'rectangle',
        name: 'Rectangle 3',
        x: 100,
        y: 300,
        width: 250,
        height: 180,
        fills: [],
        strokes: [{ color: 0xFFFACC15, width: 3, alignment: 'inside' }],
        properties: { frameId: SHAPE_FRAME_ID },
      },
      // Purple circle
      {
        id: SHAPE_ELLIPSE_2_ID,
        projectId: DEMO_PROJECT_ID,
        frameId: null,
        type: 'ellipse',
        name: 'Circle 1',
        x: 480,
        y: 330,
        width: 140,
        height: 140,
        fills: [{ color: 0xFFA855F7 }],
        strokes: [{ color: 0xFF9333EA, width: 2 }],
        properties: { frameId: SHAPE_FRAME_ID },
      },
    ];

    for (const shape of shapesData) {
      await db.insert(schema.shapes).values({
        id: shape.id,
        projectId: shape.projectId,
        frameId: shape.frameId,
        type: shape.type,
        name: shape.name,
        x: shape.x,
        y: shape.y,
        width: shape.width,
        height: shape.height,
        fills: shape.fills,
        strokes: shape.strokes,
        properties: shape.properties,
      });
    }

    console.log('✅ Seed completed successfully!');
    console.log('');
    console.log('📋 Demo IDs:');
    console.log(`   Project ID: ${DEMO_PROJECT_ID}`);
    console.log(`   Branch ID:  ${DEMO_BRANCH_ID}`);
    console.log(`   Frame ID:   ${DEMO_FRAME_ID}`);
    console.log('');
    console.log('🚀 You can now load this project in the Flutter app!');

  } catch (error) {
    console.error('❌ Seed failed:', error);
    process.exit(1);
  }

  process.exit(0);
}

seed();
