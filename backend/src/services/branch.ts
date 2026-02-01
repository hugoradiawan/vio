import { create } from "@bufbuild/protobuf";
import type { ServiceImpl } from "@connectrpc/connect";
import { and, eq } from "drizzle-orm";
import { db, schema } from "../db";
import {
	BranchSchema,
	BranchService,
	CompareBranchesResponseSchema,
	CreateBranchResponseSchema,
	GetBranchResponseSchema,
	ListBranchesResponseSchema,
	MergeBranchesResponseSchema,
	UpdateBranchResponseSchema,
	type Branch,
	type CompareBranchesResponse,
	type CreateBranchResponse,
	type GetBranchResponse,
	type ListBranchesResponse,
	type MergeBranchesResponse,
	type UpdateBranchResponse,
} from "../gen/vio/v1/branch_pb.js";
import { CommitSchema, type Commit } from "../gen/vio/v1/commit_pb.js";
import { EmptySchema, MergeStrategy, TimestampSchema, type Empty, type Timestamp } from "../gen/vio/v1/common_pb.js";
import { alreadyExists, failedPrecondition, internal, notFound } from "./errors.js";
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
	return create(TimestampSchema, {
		millis: BigInt(date.getTime()),
	});
}

function toProtoBranch(dbBranch: typeof schema.branches.$inferSelect): Branch {
	return create(BranchSchema, {
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
	});
}

function toProtoCommit(dbCommit: typeof schema.commits.$inferSelect): Commit {
	return create(CommitSchema, {
		id: dbCommit.id,
		projectId: dbCommit.projectId,
		branchId: dbCommit.branchId,
		parentId: dbCommit.parentId ?? undefined,
		message: dbCommit.message,
		authorId: dbCommit.authorId,
		snapshotId: dbCommit.snapshotId,
		createdAt: toProtoTimestamp(new Date(dbCommit.createdAt)),
	});
}

export const branchServiceImpl: ServiceImpl<typeof BranchService> = {
	async listBranches(req): Promise<ListBranchesResponse> {
		const branches = await db
			.select()
			.from(schema.branches)
			.where(eq(schema.branches.projectId, req.projectId));

		return create(ListBranchesResponseSchema, {
			branches: branches.map(toProtoBranch),
		});
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
			throw notFound("Branch not found");
		}

		return create(GetBranchResponseSchema, {
			branch: toProtoBranch(branch),
			headCommit: branch.headCommit
				? toProtoCommit(branch.headCommit)
				: undefined,
		});
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
			throw alreadyExists("Branch with this name already exists");
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

		return create(CreateBranchResponseSchema, {
			branch: toProtoBranch(branch),
		});
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
			throw notFound("Branch not found");
		}

		return create(UpdateBranchResponseSchema, {
			branch: toProtoBranch(updated),
		});
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
			throw notFound("Branch not found");
		}

		if (branch.isDefault) {
			throw failedPrecondition("Cannot delete the default branch");
		}

		if (branch.isProtected) {
			throw failedPrecondition("Cannot delete a protected branch");
		}

		await db
			.delete(schema.branches)
			.where(eq(schema.branches.id, req.branchId));

		return create(EmptySchema, {});
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
			throw notFound("Branch not found");
		}

		if (!sourceBranch.headCommitId) {
			throw failedPrecondition("Source branch has no commits");
		}

		// Check for fast-forward possibility
		const isFastForward = await canFastForward(sourceBranchId, targetBranchId);

		// Handle fast-forward strategy
		if (strategy === MergeStrategy.FAST_FORWARD) {
			if (!isFastForward) {
				throw failedPrecondition("Fast-forward merge not possible, branches have diverged");
			}

			await performFastForward(targetBranchId, sourceBranch.headCommitId);

			// Get updated branch
			const updatedBranch = await db.query.branches.findFirst({
				where: eq(schema.branches.id, targetBranchId),
			});

			if (!updatedBranch) {
				throw internal("Branch not found after update");
			}

			return create(MergeBranchesResponseSchema, {
				targetBranch: toProtoBranch(updatedBranch),
				mergeCommit: undefined,
				wasFastForward: true,
			});
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
			throw internal("Source snapshot not found");
		}

		// Perform three-way merge
		const mergeResult = performThreeWayMerge(
			baseSnapshot,
			sourceSnapshot,
			targetSnapshot ?? { shapes: [] },
		);

		if (!mergeResult.success) {
			throw failedPrecondition(
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
			throw internal("Branch not found after update");
		}

		return create(MergeBranchesResponseSchema, {
			targetBranch: toProtoBranch(updatedBranch),
			mergeCommit: toProtoCommit(mergeCommit),
			wasFastForward: false,
		});
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
			throw notFound("Branch not found");
		}

		// Find common ancestor
		const commonAncestor = await findCommonAncestor(baseBranchId, headBranchId);

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

		return create(CompareBranchesResponseSchema, {
			commonAncestorId: commonAncestor?.id,
			commitsAhead: ahead,
			commitsBehind: behind,
			diff: mergeResult.diff,
			mergeable: mergeResult.success,
			conflicts: mergeResult.conflicts,
		});
	},
};
