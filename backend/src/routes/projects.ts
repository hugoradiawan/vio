import { eq } from 'drizzle-orm';
import { Elysia, t } from 'elysia';
import { db, schema } from '../db';

export const projectRoutes = new Elysia({ prefix: '/api/projects' })
  .get(
    '/',
    async () => {
      const projects = await db.select().from(schema.projects);
      return { data: projects };
    },
    {
      detail: {
        tags: ['Projects'],
        summary: 'List all projects',
      },
    },
  )
  .get(
    '/:projectId',
    async ({ params, set }) => {
      const project = await db.query.projects.findFirst({
        where: eq(schema.projects.id, params.projectId),
        with: {
          branches: true,
          frames: true,
        },
      });

      if (!project) {
        set.status = 404;
        return { error: 'Project not found' };
      }

      return { data: project };
    },
    {
      params: t.Object({
        projectId: t.String(),
      }),
      detail: {
        tags: ['Projects'],
        summary: 'Get project by ID',
      },
    },
  )
  .post(
    '/',
    async ({ body }) => {
      const [project] = await db
        .insert(schema.projects)
        .values({
          name: body.name,
          description: body.description,
          ownerId: body.ownerId,
          teamId: body.teamId,
        })
        .returning();

      // Create default "main" branch
      const [mainBranch] = await db
        .insert(schema.branches)
        .values({
          projectId: project.id,
          name: 'main',
          isDefault: true,
          createdById: body.ownerId,
        })
        .returning();

      // Update project with default branch
      await db
        .update(schema.projects)
        .set({ defaultBranchId: mainBranch.id })
        .where(eq(schema.projects.id, project.id));

      // Create initial frame
      await db.insert(schema.frames).values({
        projectId: project.id,
        name: 'Frame 1',
        x: 0,
        y: 0,
        width: 800,
        height: 600,
      });

      return {
        data: {
          ...project,
          defaultBranchId: mainBranch.id,
        },
      };
    },
    {
      body: t.Object({
        name: t.String({ minLength: 1, maxLength: 255 }),
        description: t.Optional(t.String()),
        ownerId: t.String({ format: 'uuid' }),
        teamId: t.Optional(t.String({ format: 'uuid' })),
      }),
      detail: {
        tags: ['Projects'],
        summary: 'Create new project',
      },
    },
  )
  .patch(
    '/:projectId',
    async ({ params, body, set }) => {
      const [updated] = await db
        .update(schema.projects)
        .set({
          name: body.name,
          description: body.description,
          isPublic: body.isPublic,
          updatedAt: new Date(),
        })
        .where(eq(schema.projects.id, params.projectId))
        .returning();

      if (!updated) {
        set.status = 404;
        return { error: 'Project not found' };
      }

      return { data: updated };
    },
    {
      params: t.Object({
        projectId: t.String(),
      }),
      body: t.Object({
        name: t.Optional(t.String({ minLength: 1, maxLength: 255 })),
        description: t.Optional(t.String()),
        isPublic: t.Optional(t.Boolean()),
      }),
      detail: {
        tags: ['Projects'],
        summary: 'Update project',
      },
    },
  )
  .delete(
    '/:projectId',
    async ({ params, set }) => {
      const [deleted] = await db
        .update(schema.projects)
        .set({ deletedAt: new Date() })
        .where(eq(schema.projects.id, params.projectId))
        .returning();

      if (!deleted) {
        set.status = 404;
        return { error: 'Project not found' };
      }

      return { success: true };
    },
    {
      params: t.Object({
        projectId: t.String(),
      }),
      detail: {
        tags: ['Projects'],
        summary: 'Delete project (soft delete)',
      },
    },
  );
