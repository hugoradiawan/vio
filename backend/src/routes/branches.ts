import { and, eq } from 'drizzle-orm';
import { Elysia, t } from 'elysia';
import { db, schema } from '../db';

export const branchRoutes = new Elysia({ prefix: '/api/projects/:projectId/branches' })
  .get(
    '/',
    async ({ params }) => {
      const branches = await db
        .select()
        .from(schema.branches)
        .where(eq(schema.branches.projectId, params.projectId));

      return { data: branches };
    },
    {
      params: t.Object({
        projectId: t.String(),
      }),
      detail: {
        tags: ['Branches'],
        summary: 'List all branches for a project',
      },
    },
  )
  .get(
    '/:branchId',
    async ({ params, set }) => {
      const branch = await db.query.branches.findFirst({
        where: and(
          eq(schema.branches.id, params.branchId),
          eq(schema.branches.projectId, params.projectId),
        ),
        with: {
          headCommit: true,
        },
      });

      if (!branch) {
        set.status = 404;
        return { error: 'Branch not found' };
      }

      return { data: branch };
    },
    {
      params: t.Object({
        projectId: t.String(),
        branchId: t.String(),
      }),
      detail: {
        tags: ['Branches'],
        summary: 'Get branch by ID',
      },
    },
  )
  .post(
    '/',
    async ({ params, body, set }) => {
      // Check if branch name already exists
      const existing = await db.query.branches.findFirst({
        where: and(
          eq(schema.branches.projectId, params.projectId),
          eq(schema.branches.name, body.name),
        ),
      });

      if (existing) {
        set.status = 409;
        return { error: 'Branch with this name already exists' };
      }

      // Get source branch to copy head commit
      let headCommitId: string | null = null;
      if (body.sourceBranchId) {
        const sourceBranch = await db.query.branches.findFirst({
          where: eq(schema.branches.id, body.sourceBranchId),
        });
        if (sourceBranch) {
          headCommitId = sourceBranch.headCommitId;
        }
      }

      const [branch] = await db
        .insert(schema.branches)
        .values({
          projectId: params.projectId,
          name: body.name,
          description: body.description,
          headCommitId,
          createdById: body.createdById,
        })
        .returning();

      return { data: branch };
    },
    {
      params: t.Object({
        projectId: t.String(),
      }),
      body: t.Object({
        name: t.String({ minLength: 1, maxLength: 255 }),
        description: t.Optional(t.String()),
        sourceBranchId: t.Optional(t.String()),
        createdById: t.String({ format: 'uuid' }),
      }),
      detail: {
        tags: ['Branches'],
        summary: 'Create new branch',
      },
    },
  )
  .patch(
    '/:branchId',
    async ({ params, body, set }) => {
      const [updated] = await db
        .update(schema.branches)
        .set({
          name: body.name,
          description: body.description,
          isProtected: body.isProtected,
          updatedAt: new Date(),
        })
        .where(
          and(
            eq(schema.branches.id, params.branchId),
            eq(schema.branches.projectId, params.projectId),
          ),
        )
        .returning();

      if (!updated) {
        set.status = 404;
        return { error: 'Branch not found' };
      }

      return { data: updated };
    },
    {
      params: t.Object({
        projectId: t.String(),
        branchId: t.String(),
      }),
      body: t.Object({
        name: t.Optional(t.String({ minLength: 1, maxLength: 255 })),
        description: t.Optional(t.String()),
        isProtected: t.Optional(t.Boolean()),
      }),
      detail: {
        tags: ['Branches'],
        summary: 'Update branch',
      },
    },
  )
  .delete(
    '/:branchId',
    async ({ params, set }) => {
      // Check if this is the default branch
      const branch = await db.query.branches.findFirst({
        where: and(
          eq(schema.branches.id, params.branchId),
          eq(schema.branches.projectId, params.projectId),
        ),
      });

      if (!branch) {
        set.status = 404;
        return { error: 'Branch not found' };
      }

      if (branch.isDefault) {
        set.status = 400;
        return { error: 'Cannot delete the default branch' };
      }

      if (branch.isProtected) {
        set.status = 400;
        return { error: 'Cannot delete a protected branch' };
      }

      await db
        .delete(schema.branches)
        .where(eq(schema.branches.id, params.branchId));

      return { success: true };
    },
    {
      params: t.Object({
        projectId: t.String(),
        branchId: t.String(),
      }),
      detail: {
        tags: ['Branches'],
        summary: 'Delete branch',
      },
    },
  );
