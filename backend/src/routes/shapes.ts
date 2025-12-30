import { and, asc, eq } from 'drizzle-orm';
import { Elysia, t } from 'elysia';
import { db, schema } from '../db';

export const shapeRoutes = new Elysia({ prefix: '/api/projects/:projectId/shapes' })
  .get(
    '/',
    async ({ params, query }) => {
      const whereClause = query.frameId
        ? and(
            eq(schema.shapes.projectId, params.projectId),
            eq(schema.shapes.frameId, query.frameId),
          )
        : eq(schema.shapes.projectId, params.projectId);

      const shapes = await db
        .select()
        .from(schema.shapes)
        .where(whereClause)
        .orderBy(asc(schema.shapes.sortOrder));

      return { data: shapes };
    },
    {
      params: t.Object({
        projectId: t.String(),
      }),
      query: t.Object({
        frameId: t.Optional(t.String()),
      }),
      detail: {
        tags: ['Shapes'],
        summary: 'List shapes in project or frame',
      },
    },
  )
  .get(
    '/:shapeId',
    async ({ params, set }) => {
      const shape = await db.query.shapes.findFirst({
        where: and(
          eq(schema.shapes.id, params.shapeId),
          eq(schema.shapes.projectId, params.projectId),
        ),
        with: {
          children: true,
        },
      });

      if (!shape) {
        set.status = 404;
        return { error: 'Shape not found' };
      }

      return { data: shape };
    },
    {
      params: t.Object({
        projectId: t.String(),
        shapeId: t.String(),
      }),
      detail: {
        tags: ['Shapes'],
        summary: 'Get shape by ID',
      },
    },
  )
  .post(
    '/',
    async ({ params, body }) => {
      const [shape] = await db
        .insert(schema.shapes)
        .values({
          projectId: params.projectId,
          frameId: body.frameId,
          parentId: body.parentId,
          type: body.type,
          name: body.name,
          x: body.x,
          y: body.y,
          width: body.width,
          height: body.height,
          rotation: body.rotation || 0,
          transformA: body.transform?.a ?? 1,
          transformB: body.transform?.b ?? 0,
          transformC: body.transform?.c ?? 0,
          transformD: body.transform?.d ?? 1,
          transformE: body.transform?.e ?? 0,
          transformF: body.transform?.f ?? 0,
          fills: body.fills || [],
          strokes: body.strokes || [],
          opacity: body.opacity ?? 1,
          properties: body.properties || {},
          sortOrder: body.sortOrder || 0,
        })
        .returning();

      return { data: shape };
    },
    {
      params: t.Object({
        projectId: t.String(),
      }),
      body: t.Object({
        frameId: t.Optional(t.String()),
        parentId: t.Optional(t.String()),
        type: t.String(),
        name: t.String(),
        x: t.Number(),
        y: t.Number(),
        width: t.Number(),
        height: t.Number(),
        rotation: t.Optional(t.Number()),
        transform: t.Optional(
          t.Object({
            a: t.Number(),
            b: t.Number(),
            c: t.Number(),
            d: t.Number(),
            e: t.Number(),
            f: t.Number(),
          }),
        ),
        fills: t.Optional(t.Array(t.Any())),
        strokes: t.Optional(t.Array(t.Any())),
        opacity: t.Optional(t.Number()),
        properties: t.Optional(t.Any()),
        sortOrder: t.Optional(t.Number()),
      }),
      detail: {
        tags: ['Shapes'],
        summary: 'Create new shape',
      },
    },
  )
  .patch(
    '/:shapeId',
    async ({ params, body, set }) => {
      const updateData: Record<string, any> = {
        updatedAt: new Date(),
      };

      // Only include provided fields
      if (body.name !== undefined) updateData.name = body.name;
      if (body.x !== undefined) updateData.x = body.x;
      if (body.y !== undefined) updateData.y = body.y;
      if (body.width !== undefined) updateData.width = body.width;
      if (body.height !== undefined) updateData.height = body.height;
      if (body.rotation !== undefined) updateData.rotation = body.rotation;
      if (body.fills !== undefined) updateData.fills = body.fills;
      if (body.strokes !== undefined) updateData.strokes = body.strokes;
      if (body.opacity !== undefined) updateData.opacity = body.opacity;
      if (body.hidden !== undefined) updateData.hidden = body.hidden;
      if (body.blocked !== undefined) updateData.blocked = body.blocked;
      if (body.properties !== undefined) updateData.properties = body.properties;
      if (body.sortOrder !== undefined) updateData.sortOrder = body.sortOrder;

      // Transform matrix
      if (body.transform) {
        updateData.transformA = body.transform.a;
        updateData.transformB = body.transform.b;
        updateData.transformC = body.transform.c;
        updateData.transformD = body.transform.d;
        updateData.transformE = body.transform.e;
        updateData.transformF = body.transform.f;
      }

      const [updated] = await db
        .update(schema.shapes)
        .set(updateData)
        .where(
          and(
            eq(schema.shapes.id, params.shapeId),
            eq(schema.shapes.projectId, params.projectId),
          ),
        )
        .returning();

      if (!updated) {
        set.status = 404;
        return { error: 'Shape not found' };
      }

      return { data: updated };
    },
    {
      params: t.Object({
        projectId: t.String(),
        shapeId: t.String(),
      }),
      body: t.Object({
        name: t.Optional(t.String()),
        x: t.Optional(t.Number()),
        y: t.Optional(t.Number()),
        width: t.Optional(t.Number()),
        height: t.Optional(t.Number()),
        rotation: t.Optional(t.Number()),
        transform: t.Optional(
          t.Object({
            a: t.Number(),
            b: t.Number(),
            c: t.Number(),
            d: t.Number(),
            e: t.Number(),
            f: t.Number(),
          }),
        ),
        fills: t.Optional(t.Array(t.Any())),
        strokes: t.Optional(t.Array(t.Any())),
        opacity: t.Optional(t.Number()),
        hidden: t.Optional(t.Boolean()),
        blocked: t.Optional(t.Boolean()),
        properties: t.Optional(t.Any()),
        sortOrder: t.Optional(t.Number()),
      }),
      detail: {
        tags: ['Shapes'],
        summary: 'Update shape',
      },
    },
  )
  .delete(
    '/:shapeId',
    async ({ params, set }) => {
      const [deleted] = await db
        .delete(schema.shapes)
        .where(
          and(
            eq(schema.shapes.id, params.shapeId),
            eq(schema.shapes.projectId, params.projectId),
          ),
        )
        .returning();

      if (!deleted) {
        set.status = 404;
        return { error: 'Shape not found' };
      }

      return { success: true };
    },
    {
      params: t.Object({
        projectId: t.String(),
        shapeId: t.String(),
      }),
      detail: {
        tags: ['Shapes'],
        summary: 'Delete shape',
      },
    },
  )
  // Batch operations for performance
  .post(
    '/batch',
    async ({ params, body }) => {
      const results = {
        created: [] as any[],
        updated: [] as any[],
        deleted: [] as string[],
      };

      // Process creates
      if (body.create?.length) {
        const created = await db
          .insert(schema.shapes)
          .values(
            body.create.map((s: any) => ({
              projectId: params.projectId,
              frameId: s.frameId,
              parentId: s.parentId,
              type: s.type,
              name: s.name,
              x: s.x,
              y: s.y,
              width: s.width,
              height: s.height,
              rotation: s.rotation || 0,
              transformA: s.transform?.a ?? 1,
              transformB: s.transform?.b ?? 0,
              transformC: s.transform?.c ?? 0,
              transformD: s.transform?.d ?? 1,
              transformE: s.transform?.e ?? 0,
              transformF: s.transform?.f ?? 0,
              fills: s.fills || [],
              strokes: s.strokes || [],
              opacity: s.opacity ?? 1,
              properties: s.properties || {},
              sortOrder: s.sortOrder || 0,
            })),
          )
          .returning();
        results.created = created;
      }

      // Process updates (one by one for now)
      if (body.update?.length) {
        for (const update of body.update) {
          const updateData: Record<string, any> = { updatedAt: new Date() };
          Object.assign(updateData, update);
          delete updateData.id;

          if (update.transform) {
            updateData.transformA = update.transform.a;
            updateData.transformB = update.transform.b;
            updateData.transformC = update.transform.c;
            updateData.transformD = update.transform.d;
            updateData.transformE = update.transform.e;
            updateData.transformF = update.transform.f;
            delete updateData.transform;
          }

          const [updated] = await db
            .update(schema.shapes)
            .set(updateData)
            .where(
              and(
                eq(schema.shapes.id, update.id),
                eq(schema.shapes.projectId, params.projectId),
              ),
            )
            .returning();
          if (updated) results.updated.push(updated);
        }
      }

      // Process deletes
      if (body.delete?.length) {
        for (const id of body.delete) {
          await db
            .delete(schema.shapes)
            .where(
              and(
                eq(schema.shapes.id, id),
                eq(schema.shapes.projectId, params.projectId),
              ),
            );
          results.deleted.push(id);
        }
      }

      return { data: results };
    },
    {
      params: t.Object({
        projectId: t.String(),
      }),
      body: t.Object({
        create: t.Optional(t.Array(t.Any())),
        update: t.Optional(t.Array(t.Any())),
        delete: t.Optional(t.Array(t.String())),
      }),
      detail: {
        tags: ['Shapes'],
        summary: 'Batch create/update/delete shapes',
      },
    },
  );
