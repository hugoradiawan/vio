import { and, desc, eq } from 'drizzle-orm';
import { Elysia, t } from 'elysia';
import { db, schema } from '../db';

export const commitRoutes = new Elysia({ prefix: '/api/projects/:projectId/commits' })
  .get(
    '/',
    async ({ params, query }) => {
      const limit = query.limit || 50;
      const offset = query.offset || 0;

      const whereClause = params.branchId
        ? and(
            eq(schema.commits.projectId, params.projectId),
            eq(schema.commits.branchId, params.branchId),
          )
        : eq(schema.commits.projectId, params.projectId);

      const commits = await db
        .select()
        .from(schema.commits)
        .where(whereClause)
        .orderBy(desc(schema.commits.createdAt))
        .limit(limit)
        .offset(offset);

      return { data: commits };
    },
    {
      params: t.Object({
        projectId: t.String(),
        branchId: t.Optional(t.String()),
      }),
      query: t.Object({
        branchId: t.Optional(t.String()),
        limit: t.Optional(t.Number({ minimum: 1, maximum: 100 })),
        offset: t.Optional(t.Number({ minimum: 0 })),
      }),
      detail: {
        tags: ['Commits'],
        summary: 'List commits for a project or branch',
      },
    },
  )
  .get(
    '/:commitId',
    async ({ params, set }) => {
      const commit = await db.query.commits.findFirst({
        where: and(
          eq(schema.commits.id, params.commitId),
          eq(schema.commits.projectId, params.projectId),
        ),
        with: {
          snapshot: true,
          parent: true,
        },
      });

      if (!commit) {
        set.status = 404;
        return { error: 'Commit not found' };
      }

      return { data: commit };
    },
    {
      params: t.Object({
        projectId: t.String(),
        commitId: t.String(),
      }),
      detail: {
        tags: ['Commits'],
        summary: 'Get commit by ID with snapshot',
      },
    },
  )
  .post(
    '/',
    async ({ params, body, set }) => {
      // Get the branch
      const branch = await db.query.branches.findFirst({
        where: and(
          eq(schema.branches.id, body.branchId),
          eq(schema.branches.projectId, params.projectId),
        ),
      });

      if (!branch) {
        set.status = 404;
        return { error: 'Branch not found' };
      }

      // Create snapshot with current canvas state
      const [snapshot] = await db
        .insert(schema.snapshots)
        .values({
          projectId: params.projectId,
          data: body.snapshotData,
        })
        .returning();

      // Create commit
      const [commit] = await db
        .insert(schema.commits)
        .values({
          projectId: params.projectId,
          branchId: body.branchId,
          parentId: branch.headCommitId,
          message: body.message,
          authorId: body.authorId,
          snapshotId: snapshot.id,
        })
        .returning();

      // Update branch head
      await db
        .update(schema.branches)
        .set({
          headCommitId: commit.id,
          updatedAt: new Date(),
        })
        .where(eq(schema.branches.id, body.branchId));

      return { data: commit };
    },
    {
      params: t.Object({
        projectId: t.String(),
      }),
      body: t.Object({
        branchId: t.String({ format: 'uuid' }),
        message: t.String({ minLength: 1, maxLength: 500 }),
        authorId: t.String({ format: 'uuid' }),
        snapshotData: t.Any(), // Canvas state JSON
      }),
      detail: {
        tags: ['Commits'],
        summary: 'Create new commit',
      },
    },
  )
  .get(
    '/:commitId/diff/:targetCommitId',
    async ({ params, set }) => {
      // Get both commits with snapshots
      const [sourceCommit, targetCommit] = await Promise.all([
        db.query.commits.findFirst({
          where: eq(schema.commits.id, params.commitId),
          with: { snapshot: true },
        }),
        db.query.commits.findFirst({
          where: eq(schema.commits.id, params.targetCommitId),
          with: { snapshot: true },
        }),
      ]);

      if (!sourceCommit || !targetCommit) {
        set.status = 404;
        return { error: 'One or both commits not found' };
      }

      // Calculate diff between snapshots
      const diff = calculateDiff(
        sourceCommit.snapshot?.data as Record<string, any>,
        targetCommit.snapshot?.data as Record<string, any>,
      );

      return {
        data: {
          source: {
            id: sourceCommit.id,
            message: sourceCommit.message,
            createdAt: sourceCommit.createdAt,
          },
          target: {
            id: targetCommit.id,
            message: targetCommit.message,
            createdAt: targetCommit.createdAt,
          },
          diff,
        },
      };
    },
    {
      params: t.Object({
        projectId: t.String(),
        commitId: t.String(),
        targetCommitId: t.String(),
      }),
      detail: {
        tags: ['Commits'],
        summary: 'Get diff between two commits',
      },
    },
  );

/**
 * Calculate the difference between two snapshots
 */
function calculateDiff(
  source: Record<string, any> | undefined,
  target: Record<string, any> | undefined,
): {
  added: string[];
  removed: string[];
  modified: string[];
} {
  if (!source || !target) {
    return { added: [], removed: [], modified: [] };
  }

  const sourceShapes = new Map(
    (source.shapes || []).map((s: any) => [s.id, s]),
  );
  const targetShapes = new Map(
    (target.shapes || []).map((s: any) => [s.id, s]),
  );

  const added: string[] = [];
  const removed: string[] = [];
  const modified: string[] = [];

  // Find added and modified
  for (const [id, shape] of targetShapes) {
    if (!sourceShapes.has(id)) {
      added.push(id);
    } else if (JSON.stringify(sourceShapes.get(id)) !== JSON.stringify(shape)) {
      modified.push(id);
    }
  }

  // Find removed
  for (const id of sourceShapes.keys()) {
    if (!targetShapes.has(id)) {
      removed.push(id);
    }
  }

  return { added, removed, modified };
}
