import { and, eq } from "drizzle-orm";
import { ServerError, Status } from "nice-grpc";
import { db, schema } from "../db";
import type {
    Branch,
    BranchServiceImplementation,
    CreateBranchResponse,
    GetBranchResponse,
    ListBranchesResponse,
    UpdateBranchResponse,
} from "../gen/vio/v1/branch.js";
import type { Commit } from "../gen/vio/v1/commit.js";
import type { Empty, Timestamp } from "../gen/vio/v1/common.js";

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
		if (req.description !== undefined)
			updateData.description = req.description;
		if (req.isProtected !== undefined)
			updateData.isProtected = req.isProtected;

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
};
