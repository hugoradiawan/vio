import { and, asc, desc, eq } from "drizzle-orm";
import { ServerError, Status } from "nice-grpc";
import { db, schema } from "../db";
import type {
	Commit,
	CommitServiceImplementation,
	CreateCommitResponse,
	GetCommitResponse,
	GetDiffResponse,
	ListCommitsResponse,
	Snapshot,
} from "../gen/vio/v1/commit.js";
import type { Timestamp } from "../gen/vio/v1/common.js";

function toProtoTimestamp(date: Date): Timestamp {
	return {
		millis: BigInt(date.getTime()),
	};
}

function toProtoCommit(dbCommit: typeof schema.commits.$inferSelect): Commit {
	return {
		id: dbCommit.id,
		projectId: dbCommit.projectId,
		branchId: dbCommit.branchId,
		parentId: dbCommit.parentId ?? undefined,
		message: dbCommit.message,
		authorId: dbCommit.authorId,
		snapshotId: dbCommit.snapshotId,
		createdAt: toProtoTimestamp(new Date(dbCommit.createdAt)),
	};
}

function toProtoSnapshot(
	dbSnapshot: typeof schema.snapshots.$inferSelect,
): Snapshot {
	return {
		id: dbSnapshot.id,
		projectId: dbSnapshot.projectId,
		data: new TextEncoder().encode(JSON.stringify(dbSnapshot.data)),
		createdAt: toProtoTimestamp(new Date(dbSnapshot.createdAt)),
	};
}

export const commitServiceImpl: CommitServiceImplementation = {
	async listCommits(req): Promise<ListCommitsResponse> {
		// Build where clause - branchId is optional
		const whereClause = req.branchId
			? and(
					eq(schema.commits.projectId, req.projectId),
					eq(schema.commits.branchId, req.branchId),
				)
			: eq(schema.commits.projectId, req.projectId);

		// Use pagination via page token if provided, default to 50 items
		const pageSize = req.page?.limit ?? 50;

		const commits = await db
			.select()
			.from(schema.commits)
			.where(whereClause)
			.orderBy(desc(schema.commits.createdAt))
			.limit(pageSize);

		return {
			commits: commits.map(toProtoCommit),
		};
	},

	async getCommit(req): Promise<GetCommitResponse> {
		const commit = await db.query.commits.findFirst({
			where: and(
				eq(schema.commits.id, req.commitId),
				eq(schema.commits.projectId, req.projectId),
			),
			with: {
				snapshot: true,
			},
		});

		if (!commit) {
			throw new ServerError(Status.NOT_FOUND, "Commit not found");
		}

		return {
			commit: toProtoCommit(commit),
			snapshot: commit.snapshot
				? toProtoSnapshot(commit.snapshot)
				: undefined,
		};
	},

	async createCommit(req): Promise<CreateCommitResponse> {
		// Get current shapes to create snapshot
		const shapes = await db
			.select()
			.from(schema.shapes)
			.where(eq(schema.shapes.projectId, req.projectId))
			.orderBy(asc(schema.shapes.sortOrder));

		// Get current branch head commit
		const branch = await db.query.branches.findFirst({
			where: and(
				eq(schema.branches.id, req.branchId),
				eq(schema.branches.projectId, req.projectId),
			),
		});

		if (!branch) {
			throw new ServerError(Status.NOT_FOUND, "Branch not found");
		}

		// Create snapshot
		const [snapshot] = await db
			.insert(schema.snapshots)
			.values({
				projectId: req.projectId,
				data: { shapes }, // Store shapes as JSON
			})
			.returning();

		// Create commit
		const [commit] = await db
			.insert(schema.commits)
			.values({
				projectId: req.projectId,
				branchId: req.branchId,
				parentId: branch.headCommitId,
				message: req.message,
				authorId: req.authorId,
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
			.where(eq(schema.branches.id, req.branchId));

		return {
			commit: toProtoCommit(commit),
		};
	},

	async getDiff(req): Promise<GetDiffResponse> {
		// Get both commits
		const [sourceCommit, targetCommit] = await Promise.all([
			db.query.commits.findFirst({
				where: eq(schema.commits.id, req.sourceCommitId),
				with: { snapshot: true },
			}),
			db.query.commits.findFirst({
				where: eq(schema.commits.id, req.targetCommitId),
				with: { snapshot: true },
			}),
		]);

		if (!sourceCommit || !targetCommit) {
			throw new ServerError(Status.NOT_FOUND, "Commit not found");
		}

		// Get shapes from both snapshots
		interface SnapshotShape {
			id: string;
			[key: string]: unknown;
		}
		interface SnapshotData {
			shapes?: SnapshotShape[];
		}

		const sourceShapes = new Map<string, SnapshotShape>();
		const targetShapes = new Map<string, SnapshotShape>();

		if (sourceCommit.snapshot?.data) {
			const data = sourceCommit.snapshot.data as SnapshotData;
			for (const shape of data.shapes || []) {
				sourceShapes.set(shape.id, shape);
			}
		}

		if (targetCommit.snapshot?.data) {
			const data = targetCommit.snapshot.data as SnapshotData;
			for (const shape of data.shapes || []) {
				targetShapes.set(shape.id, shape);
			}
		}

		// Calculate diff
		const addedShapeIds: string[] = [];
		const removedShapeIds: string[] = [];
		const modifiedShapeIds: string[] = [];

		// Find added and modified shapes
		for (const [id, targetShape] of targetShapes) {
			const sourceShape = sourceShapes.get(id);
			if (!sourceShape) {
				addedShapeIds.push(id);
			} else if (
				JSON.stringify(sourceShape) !== JSON.stringify(targetShape)
			) {
				modifiedShapeIds.push(id);
			}
		}

		// Find deleted shapes
		for (const [id] of sourceShapes) {
			if (!targetShapes.has(id)) {
				removedShapeIds.push(id);
			}
		}

		return {
			source: {
				id: sourceCommit.id,
				message: sourceCommit.message,
				createdAt: toProtoTimestamp(new Date(sourceCommit.createdAt)),
			},
			target: {
				id: targetCommit.id,
				message: targetCommit.message,
				createdAt: toProtoTimestamp(new Date(targetCommit.createdAt)),
			},
			diff: {
				addedShapeIds,
				removedShapeIds,
				modifiedShapeIds,
			},
		};
	},
};
