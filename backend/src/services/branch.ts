import type { ConnectRouter } from "@connectrpc/connect";
import { Code, ConnectError } from "@connectrpc/connect";
import { and, eq } from "drizzle-orm";
import { db, schema } from "../db";
import { BranchService } from "../gen/vio/v1/branch_connect.js";
import {
    Branch,
    CreateBranchResponse,
    GetBranchResponse,
    ListBranchesResponse,
    UpdateBranchResponse,
} from "../gen/vio/v1/branch_pb.js";
import { Commit } from "../gen/vio/v1/commit_pb.js";
import { Timestamp as ProtoTimestamp } from "../gen/vio/v1/common_pb.js";

function toProtoTimestamp(date: Date): ProtoTimestamp {
	return new ProtoTimestamp({
		millis: BigInt(date.getTime()),
	});
}

function toProtoBranch(dbBranch: typeof schema.branches.$inferSelect): Branch {
	return new Branch({
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
	return new Commit({
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

export function registerBranchService(router: ConnectRouter) {
	router.service(BranchService, {
		async listBranches(req) {
			const branches = await db
				.select()
				.from(schema.branches)
				.where(eq(schema.branches.projectId, req.projectId));

			return new ListBranchesResponse({
				branches: branches.map(toProtoBranch),
			});
		},

		async getBranch(req) {
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
				throw new ConnectError("Branch not found", Code.NotFound);
			}

			return new GetBranchResponse({
				branch: toProtoBranch(branch),
				headCommit: branch.headCommit
					? toProtoCommit(branch.headCommit)
					: undefined,
			});
		},

		async createBranch(req) {
			// Check if branch name already exists
			const existing = await db.query.branches.findFirst({
				where: and(
					eq(schema.branches.projectId, req.projectId),
					eq(schema.branches.name, req.name),
				),
			});

			if (existing) {
				throw new ConnectError(
					"Branch with this name already exists",
					Code.AlreadyExists,
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

			return new CreateBranchResponse({
				branch: toProtoBranch(branch),
			});
		},

		async updateBranch(req) {
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
				throw new ConnectError("Branch not found", Code.NotFound);
			}

			return new UpdateBranchResponse({
				branch: toProtoBranch(updated),
			});
		},

		async deleteBranch(req) {
			// Check if this is the default branch
			const branch = await db.query.branches.findFirst({
				where: and(
					eq(schema.branches.id, req.branchId),
					eq(schema.branches.projectId, req.projectId),
				),
			});

			if (!branch) {
				throw new ConnectError("Branch not found", Code.NotFound);
			}

			if (branch.isDefault) {
				throw new ConnectError(
					"Cannot delete the default branch",
					Code.FailedPrecondition,
				);
			}

			if (branch.isProtected) {
				throw new ConnectError(
					"Cannot delete a protected branch",
					Code.FailedPrecondition,
				);
			}

			await db
				.delete(schema.branches)
				.where(eq(schema.branches.id, req.branchId));

			return {};
		},
	});
}
