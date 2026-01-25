import { and, asc, desc, eq } from "drizzle-orm";
import { ServerError, Status } from "nice-grpc";
import { db, schema } from "../db";
import type {
    CheckoutCommitResponse,
    CherryPickResponse,
    Commit,
    CommitServiceImplementation,
    CreateCommitResponse,
    GetCommitResponse,
    GetDiffResponse,
    ListCommitsResponse,
    RevertCommitResponse,
    Snapshot,
} from "../gen/vio/v1/commit.js";
import type { Timestamp } from "../gen/vio/v1/common.js";
import {
    getSnapshotData,
    performThreeWayMerge,
    type SnapshotData
} from "./merge.js";

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
			snapshot: commit.snapshot ? toProtoSnapshot(commit.snapshot) : undefined,
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
			} else if (JSON.stringify(sourceShape) !== JSON.stringify(targetShape)) {
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

	async checkoutCommit(req): Promise<CheckoutCommitResponse> {
		const { projectId, branchId, commitId, authorId } = req;

		// Verify commit exists and belongs to project
		const commit = await db.query.commits.findFirst({
			where: and(
				eq(schema.commits.id, commitId),
				eq(schema.commits.projectId, projectId),
			),
			with: { snapshot: true },
		});

		if (!commit) {
			throw new ServerError(Status.NOT_FOUND, "Commit not found");
		}

		// Verify branch exists
		const branch = await db.query.branches.findFirst({
			where: and(
				eq(schema.branches.id, branchId),
				eq(schema.branches.projectId, projectId),
			),
		});

		if (!branch) {
			throw new ServerError(Status.NOT_FOUND, "Branch not found");
		}

		// Get snapshot data from the target commit
		const snapshotData = commit.snapshot?.data as SnapshotData | undefined;
		if (!snapshotData) {
			throw new ServerError(Status.INTERNAL, "Commit snapshot not found");
		}

		// Create a new snapshot with the same data
		const [newSnapshot] = await db
			.insert(schema.snapshots)
			.values({
				projectId,
				data: snapshotData,
			})
			.returning();

		// Create a new commit for the checkout
		const [newCommit] = await db
			.insert(schema.commits)
			.values({
				projectId,
				branchId,
				parentId: branch.headCommitId,
				message: `Checkout to commit: ${commit.message}`,
				authorId,
				snapshotId: newSnapshot.id,
			})
			.returning();

		// Update branch head
		await db
			.update(schema.branches)
			.set({
				headCommitId: newCommit.id,
				updatedAt: new Date(),
			})
			.where(eq(schema.branches.id, branchId));

		return {
			commit: toProtoCommit(newCommit),
			restoredFrom: toProtoCommit(commit),
		};
	},

	async revertCommit(req): Promise<RevertCommitResponse> {
		const { projectId, branchId, commitId, authorId, message } = req;

		// Verify commit exists
		const commitToRevert = await db.query.commits.findFirst({
			where: and(
				eq(schema.commits.id, commitId),
				eq(schema.commits.projectId, projectId),
			),
		});

		if (!commitToRevert) {
			throw new ServerError(Status.NOT_FOUND, "Commit to revert not found");
		}

		// Get parent commit to revert to
		if (!commitToRevert.parentId) {
			throw new ServerError(
				Status.FAILED_PRECONDITION,
				"Cannot revert the initial commit",
			);
		}

		const parentCommit = await db.query.commits.findFirst({
			where: eq(schema.commits.id, commitToRevert.parentId),
			with: { snapshot: true },
		});

		if (!parentCommit?.snapshot) {
			throw new ServerError(
				Status.INTERNAL,
				"Parent commit snapshot not found",
			);
		}

		// Get branch
		const branch = await db.query.branches.findFirst({
			where: and(
				eq(schema.branches.id, branchId),
				eq(schema.branches.projectId, projectId),
			),
			with: { headCommit: { with: { snapshot: true } } },
		});

		if (!branch) {
			throw new ServerError(Status.NOT_FOUND, "Branch not found");
		}

		// Get current branch state and parent state for three-way merge
		const currentSnapshot = branch.headCommit?.snapshot?.data as
			| SnapshotData
			| undefined;
		const parentSnapshot = parentCommit.snapshot.data as SnapshotData;
		const revertSnapshot = await getSnapshotData(commitToRevert.snapshotId);

		if (!currentSnapshot || !revertSnapshot) {
			throw new ServerError(Status.INTERNAL, "Snapshot data not found");
		}

		// Perform three-way merge:
		// - Base: the commit we're reverting
		// - Source: the parent of that commit (the state we want to go back to)
		// - Target: current branch state (to preserve other changes made since)
		const mergeResult = performThreeWayMerge(
			revertSnapshot, // base - the commit being reverted
			parentSnapshot, // source - state before the reverted commit
			currentSnapshot, // target - current state
		);

		if (!mergeResult.success) {
			throw new ServerError(
				Status.FAILED_PRECONDITION,
				`Revert has conflicts: ${mergeResult.conflicts.length} shape(s) with conflicting changes`,
			);
		}

		// Create new snapshot with reverted data
		const [newSnapshot] = await db
			.insert(schema.snapshots)
			.values({
				projectId,
				data: { shapes: mergeResult.mergedShapes, version: 1 },
			})
			.returning();

		// Create revert commit
		const revertMessage = message || `Revert "${commitToRevert.message}"`;
		const [revertCommit] = await db
			.insert(schema.commits)
			.values({
				projectId,
				branchId,
				parentId: branch.headCommitId,
				message: revertMessage,
				authorId,
				snapshotId: newSnapshot.id,
			})
			.returning();

		// Update branch head
		await db
			.update(schema.branches)
			.set({
				headCommitId: revertCommit.id,
				updatedAt: new Date(),
			})
			.where(eq(schema.branches.id, branchId));

		return {
			revertCommit: toProtoCommit(revertCommit),
			revertedCommit: toProtoCommit(commitToRevert),
		};
	},

	async cherryPick(req): Promise<CherryPickResponse> {
		const { projectId, targetBranchId, commitId, authorId, message } = req;

		// Verify commit exists
		const commitToPick = await db.query.commits.findFirst({
			where: and(
				eq(schema.commits.id, commitId),
				eq(schema.commits.projectId, projectId),
			),
			with: { snapshot: true },
		});

		if (!commitToPick?.snapshot) {
			throw new ServerError(
				Status.NOT_FOUND,
				"Commit to cherry-pick not found",
			);
		}

		// Get parent of the commit to pick (to compute the diff/changes introduced)
		const parentCommit = commitToPick.parentId
			? await db.query.commits.findFirst({
					where: eq(schema.commits.id, commitToPick.parentId),
					with: { snapshot: true },
				})
			: null;

		// Get target branch
		const targetBranch = await db.query.branches.findFirst({
			where: and(
				eq(schema.branches.id, targetBranchId),
				eq(schema.branches.projectId, projectId),
			),
			with: { headCommit: { with: { snapshot: true } } },
		});

		if (!targetBranch) {
			throw new ServerError(Status.NOT_FOUND, "Target branch not found");
		}

		// Three-way merge:
		// - Base: parent of the commit being picked (or empty if no parent)
		// - Source: the commit being picked (changes we want to apply)
		// - Target: current target branch state
		const baseSnapshot = parentCommit?.snapshot?.data
			? (parentCommit.snapshot.data as SnapshotData)
			: { shapes: [] };

		const pickSnapshot = commitToPick.snapshot.data as SnapshotData;
		const targetSnapshot = targetBranch.headCommit?.snapshot?.data
			? (targetBranch.headCommit.snapshot.data as SnapshotData)
			: { shapes: [] };

		const mergeResult = performThreeWayMerge(
			baseSnapshot, // base - state before the picked commit
			pickSnapshot, // source - state after the picked commit (changes to apply)
			targetSnapshot, // target - current target branch state
		);

		if (!mergeResult.success) {
			throw new ServerError(
				Status.FAILED_PRECONDITION,
				`Cherry-pick has conflicts: ${mergeResult.conflicts.length} shape(s) with conflicting changes`,
			);
		}

		// Create new snapshot
		const [newSnapshot] = await db
			.insert(schema.snapshots)
			.values({
				projectId,
				data: { shapes: mergeResult.mergedShapes, version: 1 },
			})
			.returning();

		// Create cherry-pick commit
		const pickMessage = message || `Cherry-pick: ${commitToPick.message}`;
		const [newCommit] = await db
			.insert(schema.commits)
			.values({
				projectId,
				branchId: targetBranchId,
				parentId: targetBranch.headCommitId,
				message: pickMessage,
				authorId,
				snapshotId: newSnapshot.id,
			})
			.returning();

		// Update target branch head
		await db
			.update(schema.branches)
			.set({
				headCommitId: newCommit.id,
				updatedAt: new Date(),
			})
			.where(eq(schema.branches.id, targetBranchId));

		return {
			newCommit: toProtoCommit(newCommit),
			sourceCommit: toProtoCommit(commitToPick),
		};
	},
};
