import { and, asc, eq } from 'drizzle-orm';
import { Elysia, t } from 'elysia';
import { db, schema } from '../db';

/**
 * Canvas routes for getting/syncing canvas state
 * These endpoints are used by the Flutter client for auto-sync
 */
export const canvasRoutes = new Elysia({
  prefix: '/api/projects/:projectId/branches/:branchId',
})
  /**
   * Get current canvas state for a branch
   * Returns all shapes with their current state
   */
  .get(
    '/canvas',
    async ({ params }) => {
      // Get all shapes for this project
      // In a full implementation, we'd get shapes from the branch's head commit snapshot
      // For now, we return all shapes in the project
      const shapes = await db
        .select()
        .from(schema.shapes)
        .where(eq(schema.shapes.projectId, params.projectId))
        .orderBy(asc(schema.shapes.sortOrder));

      // Get the branch to check version
      const branch = await db.query.branches.findFirst({
        where: and(
          eq(schema.branches.id, params.branchId),
          eq(schema.branches.projectId, params.projectId),
        ),
      });

      // Use updatedAt timestamp as version number (epoch milliseconds)
      const version = branch?.updatedAt
        ? new Date(branch.updatedAt).getTime()
        : Date.now();

      return {
        data: {
          shapes: shapes.map((shape) => ({
            id: shape.id,
            type: shape.type,
            name: shape.name,
            parentId: shape.parentId,
            frameId: shape.frameId,
            x: shape.x,
            y: shape.y,
            width: shape.width,
            height: shape.height,
            rotation: shape.rotation,
            transformA: shape.transformA,
            transformB: shape.transformB,
            transformC: shape.transformC,
            transformD: shape.transformD,
            transformE: shape.transformE,
            transformF: shape.transformF,
            fills: shape.fills,
            strokes: shape.strokes,
            opacity: shape.opacity,
            hidden: shape.hidden,
            blocked: shape.blocked,
            properties: shape.properties,
          })),
          version,
          lastModified: branch?.updatedAt || new Date().toISOString(),
        },
      };
    },
    {
      params: t.Object({
        projectId: t.String(),
        branchId: t.String(),
      }),
      detail: {
        tags: ['Canvas'],
        summary: 'Get canvas state for a branch',
        description:
          'Returns all shapes and current version for synchronization',
      },
    },
  )
  /**
   * Sync canvas changes from client
   * Implements last-write-wins conflict resolution
   */
  .post(
    '/sync',
    async ({ params, body }) => {
      const { shapes, localVersion, operations } = body;

      // Get current server version
      const branch = await db.query.branches.findFirst({
        where: and(
          eq(schema.branches.id, params.branchId),
          eq(schema.branches.projectId, params.projectId),
        ),
      });

      if (!branch) {
        return {
          success: false,
          serverVersion: 0,
          message: 'Branch not found',
        };
      }

      const serverVersion = branch.updatedAt
        ? new Date(branch.updatedAt).getTime()
        : 0;

      // Process operations
      for (const op of operations) {
        try {
          switch (op.type) {
            case 'create':
              if (op.shape) {
                await db.insert(schema.shapes).values({
                  id: op.shapeId,
                  projectId: params.projectId,
                  frameId: op.shape.frameId,
                  parentId: op.shape.parentId,
                  type: op.shape.type,
                  name: op.shape.name,
                  x: op.shape.x,
                  y: op.shape.y,
                  width: op.shape.width,
                  height: op.shape.height,
                  rotation: op.shape.rotation || 0,
                  transformA: op.shape.transformA ?? 1,
                  transformB: op.shape.transformB ?? 0,
                  transformC: op.shape.transformC ?? 0,
                  transformD: op.shape.transformD ?? 1,
                  transformE: op.shape.transformE ?? 0,
                  transformF: op.shape.transformF ?? 0,
                  fills: op.shape.fills || [],
                  strokes: op.shape.strokes || [],
                  opacity: op.shape.opacity ?? 1,
                  hidden: op.shape.hidden ?? false,
                  blocked: op.shape.blocked ?? false,
                  properties: op.shape.properties || {},
                });
              }
              break;

            case 'update':
              if (op.shape) {
                await db
                  .update(schema.shapes)
                  .set({
                    frameId: op.shape.frameId,
                    parentId: op.shape.parentId,
                    type: op.shape.type,
                    name: op.shape.name,
                    x: op.shape.x,
                    y: op.shape.y,
                    width: op.shape.width,
                    height: op.shape.height,
                    rotation: op.shape.rotation || 0,
                    transformA: op.shape.transformA ?? 1,
                    transformB: op.shape.transformB ?? 0,
                    transformC: op.shape.transformC ?? 0,
                    transformD: op.shape.transformD ?? 1,
                    transformE: op.shape.transformE ?? 0,
                    transformF: op.shape.transformF ?? 0,
                    fills: op.shape.fills || [],
                    strokes: op.shape.strokes || [],
                    opacity: op.shape.opacity ?? 1,
                    hidden: op.shape.hidden ?? false,
                    blocked: op.shape.blocked ?? false,
                    properties: op.shape.properties || {},
                    updatedAt: new Date(),
                  })
                  .where(
                    and(
                      eq(schema.shapes.id, op.shapeId),
                      eq(schema.shapes.projectId, params.projectId),
                    ),
                  );
              }
              break;

            case 'delete':
              await db
                .delete(schema.shapes)
                .where(
                  and(
                    eq(schema.shapes.id, op.shapeId),
                    eq(schema.shapes.projectId, params.projectId),
                  ),
                );
              break;
          }
        } catch (error) {
          console.error(`Failed to process operation ${op.type}:`, error);
        }
      }

      // Update branch timestamp
      const newVersion = Date.now();
      await db
        .update(schema.branches)
        .set({ updatedAt: new Date(newVersion) })
        .where(eq(schema.branches.id, params.branchId));

      // Check if client needs full refresh (version too old or conflict)
      const needsRefresh = localVersion < serverVersion;

      if (needsRefresh) {
        // Return updated shapes for client to merge
        const updatedShapes = await db
          .select()
          .from(schema.shapes)
          .where(eq(schema.shapes.projectId, params.projectId))
          .orderBy(asc(schema.shapes.sortOrder));

        return {
          success: true,
          serverVersion: newVersion,
          shapes: updatedShapes.map((shape) => ({
            id: shape.id,
            type: shape.type,
            name: shape.name,
            parentId: shape.parentId,
            frameId: shape.frameId,
            x: shape.x,
            y: shape.y,
            width: shape.width,
            height: shape.height,
            rotation: shape.rotation,
            transformA: shape.transformA,
            transformB: shape.transformB,
            transformC: shape.transformC,
            transformD: shape.transformD,
            transformE: shape.transformE,
            transformF: shape.transformF,
            fills: shape.fills,
            strokes: shape.strokes,
            opacity: shape.opacity,
            hidden: shape.hidden,
            blocked: shape.blocked,
            properties: shape.properties,
          })),
          message: 'Synced with server refresh',
        };
      }

      return {
        success: true,
        serverVersion: newVersion,
        message: 'Synced successfully',
      };
    },
    {
      params: t.Object({
        projectId: t.String(),
        branchId: t.String(),
      }),
      body: t.Object({
        shapes: t.Array(t.Any()),
        localVersion: t.Number(),
        operations: t.Array(
          t.Object({
            type: t.Union([
              t.Literal('create'),
              t.Literal('update'),
              t.Literal('delete'),
            ]),
            shapeId: t.String(),
            shape: t.Optional(t.Any()),
            timestamp: t.String(),
          }),
        ),
      }),
      detail: {
        tags: ['Canvas'],
        summary: 'Sync canvas changes',
        description:
          'Submit local changes and receive server state (last-write-wins)',
      },
    },
  );
