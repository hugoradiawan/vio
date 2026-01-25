import { and, eq } from "drizzle-orm";
import { ServerError, Status } from "nice-grpc";
import { db, schema } from "../db";
import type {
	Branch,
	BranchServiceImplementation,
	CompareBranchesResponse,
	CreateBranchResponse,
	GetBranchResponse,
	ListBranchesResponse,
	MergeBranchesResponse,
	UpdateBranchResponse,
} from "../gen/vio/v1/branch.js";
import type { Commit } from "../gen/vio/v1/commit.js";
import {
	MergeStrategy,
	type Empty,
	type Timestamp,
} from "../gen/vio/v1/common.js";
import {
	canFastForward,
	countCommitsDivergence,
	createMergeCommit,
	findCommonAncestor,
	getSnapshotData,
	performFastForward,
	performThreeWayMerge,
} from "./merge.js";

function toProtoTimestamp(date: Date): Timestamp {
	return {
		millis: BigInt(date.getTime()),
	};
}

function toProtoBranch(dbBranch: typeof schema.branches.$inferSelect): Branch {
	return {
		id: dbBranch.id,
		projectId: dbBranch.projectId,
		name: dbBranch.name,
		description: dbBranch.description ?? undefined,
		headCommitId: dbBranch.headCommitId ?? undefined,
		isDefault: dbBranch.isDefault,
		isProtected: dbBranch.isProtected,
		createdById: dbBranch.createdById,
		createdAt: toProtoTimestamp(new Date(dbBranch.createdAt)),
		updatedAt: toProtoTimestamp(new Date(dbBranch.updatedAt)),
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

export const branchServiceImpl: BranchServiceImplementation = {
	async listBranches(req): Promise<ListBranchesResponse> {
		const branches = await db
			.select()
			.from(schema.branches)
			.where(eq(schema.branches.projectId, req.projectId));

		return {
			branches: branches.map(toProtoBranch),
		};
	},

	async getBranch(req): Promise<GetBranchResponse> {
		const branch = await db.query.branches.findFirst({
			where: and(
				eq(schema.branches.id, req.branchId),
				eq(schema.branches.projectId, req.projectId),
			),
			with: {
				headCommit: true,
			},
		});

		if (!branch) {
			throw new ServerError(Status.NOT_FOUND, "Branch not found");
		}

		return {
			branch: toProtoBranch(branch),
			headCommit: branch.headCommit
				? toProtoCommit(branch.headCommit)
				: undefined,
		};
	},

	async createBranch(req): Promise<CreateBranchResponse> {
		// Check if branch name already exists
		const existing = await db.query.branches.findFirst({
			where: and(
				eq(schema.branches.projectId, req.projectId),
				eq(schema.branches.name, req.name),
			),
		});

		if (existing) {
			throw new ServerError(
				Status.ALREADY_EXISTS,
				"Branch with this name already exists",
			);
		}

		// Get source branch to copy head commit
		let headCommitId: string | null = null;
		if (req.sourceBranchId) {
			const sourceBranch = await db.query.branches.findFirst({
				where: eq(schema.branches.id, req.sourceBranchId),
			});
			if (sourceBranch) {
				headCommitId = sourceBranch.headCommitId;
			}
		}

		const [branch] = await db
			.insert(schema.branches)
			.values({
				projectId: req.projectId,
				name: req.name,
				description: req.description,
				headCommitId,
				createdById: req.createdById,
			})
			.returning();

		return {
			branch: toProtoBranch(branch),
		};
	},

	async updateBranch(req): Promise<UpdateBranchResponse> {
		const updateData: Partial<typeof schema.branches.$inferInsert> = {
			updatedAt: new Date(),
		};

		if (req.name) updateData.name = req.name;
		if (req.description !== undefined) updateData.description = req.description;
		if (req.isProtected !== undefined) updateData.isProtected = req.isProtected;

		const [updated] = await db
			.update(schema.branches)
			.set(updateData)
			.where(
				and(
					eq(schema.branches.id, req.branchId),
					eq(schema.branches.projectId, req.projectId),
				),
			)
			.returning();

		if (!updated) {
			throw new ServerError(Status.NOT_FOUND, "Branch not found");
		}

		return {
			branch: toProtoBranch(updated),
		};
	},

	async deleteBranch(req): Promise<Empty> {
		// Check if this is the default branch
		const branch = await db.query.branches.findFirst({
			where: and(
				eq(schema.branches.id, req.branchId),
				eq(schema.branches.projectId, req.projectId),
			),
		});

		if (!branch) {
			throw new ServerError(Status.NOT_FOUND, "Branch not found");
		}

		if (branch.isDefault) {
			throw new ServerError(
				Status.FAILED_PRECONDITION,
				"Cannot delete the default branch",
			);
		}

		if (branch.isProtected) {
			throw new ServerError(
				Status.FAILED_PRECONDITION,
				"Cannot delete a protected branch",
			);
		}

		await db
			.delete(schema.branches)
			.where(eq(schema.branches.id, req.branchId));

		return {};
	},

	async mergeBranches(req): Promise<MergeBranchesResponse> {
		const {
			projectId,
			sourceBranchId,
			targetBranchId,
			strategy,
			mergedById,
			commitMessage,
		} = req;

		// Verify both branches exist and belong to the project
		const sourceBranch = await db.query.branches.findFirst({
			where: and(
				eq(schema.branches.id, sourceBranchId),
				eq(schema.branches.projectId, projectId),
			),
			with: { headCommit: true },
		});

		const targetBranch = await db.query.branches.findFirst({
			where: and(
				eq(schema.branches.id, targetBranchId),
				eq(schema.branches.projectId, projectId),
			),
			with: { headCommit: true },
		});

		if (!sourceBranch || !targetBranch) {
			throw new ServerError(Status.NOT_FOUND, "Branch not found");
		}

		if (!sourceBranch.headCommitId) {
			throw new ServerError(
				Status.FAILED_PRECONDITION,
				"Source branch has no commits",
			);
		}

		// Check for fast-forward possibility
		const isFastForward = await canFastForward(sourceBranchId, targetBranchId);

		// Handle fast-forward strategy
		if (strategy === MergeStrategy.MERGE_STRATEGY_FAST_FORWARD) {
			if (!isFastForward) {
				throw new ServerError(
					Status.FAILED_PRECONDITION,
					"Fast-forward merge not possible, branches have diverged",
				);
			}

			await performFastForward(targetBranchId, sourceBranch.headCommitId);

			// Get updated branch
			const updatedBranch = await db.query.branches.findFirst({
				where: eq(schema.branches.id, targetBranchId),
			});

			if (!updatedBranch) {
				throw new ServerError(Status.INTERNAL, "Branch not found after update");
			}

			return {
				targetBranch: toProtoBranch(updatedBranch),
				mergeCommit: undefined,
				wasFastForward: true,
			};
		}

		// Perform actual merge
		// Get snapshots for three-way merge
		const commonAncestor = await findCommonAncestor(
			sourceBranchId,
			targetBranchId,
		);

		const baseSnapshot = commonAncestor?.snapshotId
			? await getSnapshotData(commonAncestor.snapshotId)
			: null;

		const sourceSnapshot = sourceBranch.headCommit
			? await getSnapshotData(sourceBranch.headCommit.snapshotId)
			: null;
		const targetSnapshot = targetBranch.headCommit
			? await getSnapshotData(targetBranch.headCommit.snapshotId)
			: { shapes: [] };

		if (!sourceSnapshot) {
			throw new ServerError(Status.INTERNAL, "Source snapshot not found");
		}

		// Perform three-way merge
		const mergeResult = performThreeWayMerge(
			baseSnapshot,
			sourceSnapshot,
			targetSnapshot ?? { shapes: [] },
		);

		if (!mergeResult.success) {
			throw new ServerError(
				Status.FAILED_PRECONDITION,
				`Merge has conflicts: ${mergeResult.conflicts.length} shape(s) with conflicting changes`,
			);
		}

		// Create merge commit
		const mergeMessage =
			commitMessage ||
			`Merge branch '${sourceBranch.name}' into '${targetBranch.name}'`;
		const mergeCommit = await createMergeCommit(
			projectId,
			targetBranchId,
			mergeResult.mergedShapes,
			mergedById,
			mergeMessage,
		);

		// Get updated branch
		const updatedBranch = await db.query.branches.findFirst({
			where: eq(schema.branches.id, targetBranchId),
		});

		if (!updatedBranch) {
			throw new ServerError(Status.INTERNAL, "Branch not found after update");
		}

		return {
			targetBranch: toProtoBranch(updatedBranch),
			mergeCommit: toProtoCommit(mergeCommit),
			wasFastForward: false,
		};
	},

	async compareBranches(req): Promise<CompareBranchesResponse> {
		const { projectId, baseBranchId, headBranchId } = req;

		// Verify branches exist
		const baseBranch = await db.query.branches.findFirst({
			where: and(
				eq(schema.branches.id, baseBranchId),
				eq(schema.branches.projectId, projectId),
			),
			with: { headCommit: true },
		});

		const headBranch = await db.query.branches.findFirst({
			where: and(
				eq(schema.branches.id, headBranchId),
				eq(schema.branches.projectId, projectId),
			),
			with: { headCommit: true },
		});

		if (!baseBranch || !headBranch) {
			throw new ServerError(Status.NOT_FOUND, "Branch not found");
		}

		// Find common ancestor
		const commonAncestor = await findCommonAncestor(
			baseBranchId,
			headBranchId,
		);

		// Count commits ahead/behind
		const { ahead, behind } = await countCommitsDivergence(
			baseBranchId,
			headBranchId,
		);

		// Get snapshots for diff calculation
		const baseSnapshot = commonAncestor?.snapshotId
			? await getSnapshotData(commonAncestor.snapshotId)
			: null;

		const headSnapshot = headBranch.headCommit
			? await getSnapshotData(headBranch.headCommit.snapshotId)
			: { shapes: [] };

		const baseHeadSnapshot = baseBranch.headCommit
			? await getSnapshotData(baseBranch.headCommit.snapshotId)
			: { shapes: [] };

		// Perform merge simulation to detect conflicts
		const mergeResult = performThreeWayMerge(
			baseSnapshot,
			headSnapshot ?? { shapes: [] },
			baseHeadSnapshot ?? { shapes: [] },
		);

		return {
			commonAncestorId: commonAncestor?.id,
			commitsAhead: ahead,
			commitsBehind: behind,
			diff: mergeResult.diff,
			mergeable: mergeResult.success,
			conflicts: mergeResult.conflicts,
		};
	},
};
