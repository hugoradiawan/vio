/**
 * Pull Request Service
 *
 * Design review workflow similar to Git PRs, adapted for design files.
 * Reference: gitea/services/pull/pull.go for PR lifecycle patterns.
 */

import { and, desc, eq } from "drizzle-orm";
import { ServerError, Status } from "nice-grpc";
import { db, schema } from "../db";
import type { Branch } from "../gen/vio/v1/branch.js";
import type { Commit } from "../gen/vio/v1/commit.js";
import type { Timestamp } from "../gen/vio/v1/common.js";
import {
    PullRequestStatus,
    type CheckMergeStatusResponse,
    type ClosePullRequestResponse,
    type CreatePullRequestResponse,
    type GetPullRequestResponse,
    type ListPullRequestsResponse,
    type MergePullRequestResponse,
    type PullRequest,
    type PullRequestServiceImplementation,
    type ReopenPullRequestResponse,
    type ResolveConflictsResponse,
    type UpdatePullRequestResponse,
} from "../gen/vio/v1/pullrequest.js";
import {
    canFastForward,
    countCommitsDivergence,
    createMergeCommit,
    findCommonAncestor,
    getSnapshotData,
    performFastForward,
    performThreeWayMerge,
    type SnapshotShape,
} from "./merge.js";

function toProtoTimestamp(date: Date): Timestamp {
	return {
		millis: BigInt(date.getTime()),
	};
}

function toProtoPullRequest(
	dbPR: typeof schema.pullRequests.$inferSelect,
): PullRequest {
	let status: PullRequestStatus;
	switch (dbPR.status) {
		case "merged":
			status = PullRequestStatus.PULL_REQUEST_STATUS_MERGED;
			break;
		case "closed":
			status = PullRequestStatus.PULL_REQUEST_STATUS_CLOSED;
			break;
		default:
			status = PullRequestStatus.PULL_REQUEST_STATUS_OPEN;
	}

	return {
		id: dbPR.id,
		projectId: dbPR.projectId,
		sourceBranchId: dbPR.sourceBranchId,
		targetBranchId: dbPR.targetBranchId,
		title: dbPR.title,
		description: dbPR.description ?? undefined,
		status,
		authorId: dbPR.authorId,
		reviewerIds: (dbPR.reviewers as string[]) ?? [],
		createdAt: toProtoTimestamp(new Date(dbPR.createdAt)),
		updatedAt: toProtoTimestamp(new Date(dbPR.updatedAt)),
		mergedAt: dbPR.mergedAt
			? toProtoTimestamp(new Date(dbPR.mergedAt))
			: undefined,
		closedAt: dbPR.closedAt
			? toProtoTimestamp(new Date(dbPR.closedAt))
			: undefined,
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

export const pullRequestServiceImpl: PullRequestServiceImplementation = {
	async listPullRequests(req): Promise<ListPullRequestsResponse> {
		const { projectId, status, authorId, page } = req;

		// Build where conditions
		const conditions: ReturnType<typeof eq>[] = [
			eq(schema.pullRequests.projectId, projectId),
		];

		if (status !== undefined && status !== PullRequestStatus.PULL_REQUEST_STATUS_UNSPECIFIED) {
			const dbStatus =
				status === PullRequestStatus.PULL_REQUEST_STATUS_MERGED
					? "merged"
					: status === PullRequestStatus.PULL_REQUEST_STATUS_CLOSED
						? "closed"
						: "open";
			conditions.push(eq(schema.pullRequests.status, dbStatus));
		}

		if (authorId) {
			conditions.push(eq(schema.pullRequests.authorId, authorId));
		}

		const pageSize = page?.limit ?? 50;

		const pullRequests = await db
			.select()
			.from(schema.pullRequests)
			.where(and(...conditions))
			.orderBy(desc(schema.pullRequests.createdAt))
			.limit(pageSize);

		return {
			pullRequests: pullRequests.map(toProtoPullRequest),
		};
	},

	async getPullRequest(req): Promise<GetPullRequestResponse> {
		const { projectId, pullRequestId } = req;

		const pr = await db.query.pullRequests.findFirst({
			where: and(
				eq(schema.pullRequests.id, pullRequestId),
				eq(schema.pullRequests.projectId, projectId),
			),
		});

		if (!pr) {
			throw new ServerError(Status.NOT_FOUND, "Pull request not found");
		}

		// Get branches with snapshots for diff/merge calculation
		const sourceBranch = await db.query.branches.findFirst({
			where: eq(schema.branches.id, pr.sourceBranchId),
			with: { headCommit: { with: { snapshot: true } } },
		});

		const targetBranch = await db.query.branches.findFirst({
			where: eq(schema.branches.id, pr.targetBranchId),
			with: { headCommit: { with: { snapshot: true } } },
		});

		// Calculate diff and conflicts
		const commonAncestor = await findCommonAncestor(
			pr.sourceBranchId,
			pr.targetBranchId,
		);

		const baseSnapshot = commonAncestor?.snapshotId
			? await getSnapshotData(commonAncestor.snapshotId)
			: null;

		interface SnapshotData {
			shapes: SnapshotShape[];
		}

		const sourceSnapshot = sourceBranch?.headCommit?.snapshot?.data
			? (sourceBranch.headCommit.snapshot.data as SnapshotData)
			: { shapes: [] };

		const targetSnapshot = targetBranch?.headCommit?.snapshot?.data
			? (targetBranch.headCommit.snapshot.data as SnapshotData)
			: { shapes: [] };

		const mergeResult = performThreeWayMerge(
			baseSnapshot,
			sourceSnapshot,
			targetSnapshot,
		);

		return {
			pullRequest: toProtoPullRequest(pr),
			diff: mergeResult.diff,
			conflicts: mergeResult.conflicts,
			mergeable: mergeResult.success,
		};
	},

	async createPullRequest(req): Promise<CreatePullRequestResponse> {
		const {
			projectId,
			sourceBranchId,
			targetBranchId,
			title,
			description,
			authorId,
			reviewerIds,
		} = req;

		// Verify branches exist
		const sourceBranch = await db.query.branches.findFirst({
			where: and(
				eq(schema.branches.id, sourceBranchId),
				eq(schema.branches.projectId, projectId),
			),
		});

		const targetBranch = await db.query.branches.findFirst({
			where: and(
				eq(schema.branches.id, targetBranchId),
				eq(schema.branches.projectId, projectId),
			),
		});

		if (!sourceBranch || !targetBranch) {
			throw new ServerError(Status.NOT_FOUND, "Branch not found");
		}

		if (sourceBranchId === targetBranchId) {
			throw new ServerError(
				Status.INVALID_ARGUMENT,
				"Source and target branches must be different",
			);
		}

		// Check for existing open PR with same source/target
		const existingPR = await db.query.pullRequests.findFirst({
			where: and(
				eq(schema.pullRequests.projectId, projectId),
				eq(schema.pullRequests.sourceBranchId, sourceBranchId),
				eq(schema.pullRequests.targetBranchId, targetBranchId),
				eq(schema.pullRequests.status, "open"),
			),
		});

		if (existingPR) {
			throw new ServerError(
				Status.ALREADY_EXISTS,
				"An open pull request already exists for these branches",
			);
		}

		// Create PR
		const [pr] = await db
			.insert(schema.pullRequests)
			.values({
				projectId,
				sourceBranchId,
				targetBranchId,
				title,
				description,
				authorId,
				reviewers: reviewerIds ?? [],
				status: "open",
			})
			.returning();

		// Calculate initial diff and conflicts
		const srcBranch = await db.query.branches.findFirst({
			where: eq(schema.branches.id, sourceBranchId),
			with: { headCommit: { with: { snapshot: true } } },
		});

		const tgtBranch = await db.query.branches.findFirst({
			where: eq(schema.branches.id, targetBranchId),
			with: { headCommit: { with: { snapshot: true } } },
		});

		const commonAncestor = await findCommonAncestor(sourceBranchId, targetBranchId);
		const baseSnapshot = commonAncestor?.snapshotId
			? await getSnapshotData(commonAncestor.snapshotId)
			: null;

		interface SnapshotData {
			shapes: SnapshotShape[];
		}

		const sourceSnapshot = srcBranch?.headCommit?.snapshot?.data
			? (srcBranch.headCommit.snapshot.data as SnapshotData)
			: { shapes: [] };

		const targetSnapshot = tgtBranch?.headCommit?.snapshot?.data
			? (tgtBranch.headCommit.snapshot.data as SnapshotData)
			: { shapes: [] };

		const mergeResult = performThreeWayMerge(
			baseSnapshot,
			sourceSnapshot,
			targetSnapshot,
		);

		return {
			pullRequest: toProtoPullRequest(pr),
			diff: mergeResult.diff,
			conflicts: mergeResult.conflicts,
		};
	},

	async updatePullRequest(req): Promise<UpdatePullRequestResponse> {
		const { projectId, pullRequestId, title, description, reviewerIds } = req;

		const pr = await db.query.pullRequests.findFirst({
			where: and(
				eq(schema.pullRequests.id, pullRequestId),
				eq(schema.pullRequests.projectId, projectId),
			),
		});

		if (!pr) {
			throw new ServerError(Status.NOT_FOUND, "Pull request not found");
		}

		if (pr.status !== "open") {
			throw new ServerError(
				Status.FAILED_PRECONDITION,
				"Cannot update a closed or merged pull request",
			);
		}

		const updateData: Partial<typeof schema.pullRequests.$inferInsert> = {
			updatedAt: new Date(),
		};

		if (title) updateData.title = title;
		if (description !== undefined) updateData.description = description;
		if (reviewerIds) updateData.reviewers = reviewerIds;

		const [updated] = await db
			.update(schema.pullRequests)
			.set(updateData)
			.where(eq(schema.pullRequests.id, pullRequestId))
			.returning();

		return {
			pullRequest: toProtoPullRequest(updated),
		};
	},

	async mergePullRequest(req): Promise<MergePullRequestResponse> {
		const { projectId, pullRequestId, strategy, mergedById, commitMessage } = req;

		const pr = await db.query.pullRequests.findFirst({
			where: and(
				eq(schema.pullRequests.id, pullRequestId),
				eq(schema.pullRequests.projectId, projectId),
			),
		});

		if (!pr) {
			throw new ServerError(Status.NOT_FOUND, "Pull request not found");
		}

		if (pr.status !== "open") {
			throw new ServerError(
				Status.FAILED_PRECONDITION,
				"Pull request is not open",
			);
		}

		// Get branches
		const sourceBranch = await db.query.branches.findFirst({
			where: eq(schema.branches.id, pr.sourceBranchId),
			with: { headCommit: { with: { snapshot: true } } },
		});

		const targetBranch = await db.query.branches.findFirst({
			where: eq(schema.branches.id, pr.targetBranchId),
			with: { headCommit: { with: { snapshot: true } } },
		});

		if (!sourceBranch || !targetBranch) {
			throw new ServerError(Status.INTERNAL, "Branch not found");
		}

		if (!sourceBranch.headCommitId) {
			throw new ServerError(
				Status.FAILED_PRECONDITION,
				"Source branch has no commits",
			);
		}

		// Check for fast-forward possibility
		const isFastForward = await canFastForward(
			pr.sourceBranchId,
			pr.targetBranchId,
		);

		let mergeCommit: typeof schema.commits.$inferSelect | undefined;
		let wasFastForward = false;

		// Get snapshots for merge
		const commonAncestor = await findCommonAncestor(
			pr.sourceBranchId,
			pr.targetBranchId,
		);

		const baseSnapshot = commonAncestor?.snapshotId
			? await getSnapshotData(commonAncestor.snapshotId)
			: null;

		interface SnapshotData {
			shapes: SnapshotShape[];
		}

		const sourceSnapshot = sourceBranch.headCommit?.snapshot?.data
			? (sourceBranch.headCommit.snapshot.data as SnapshotData)
			: { shapes: [] };

		const targetSnapshot = targetBranch.headCommit?.snapshot?.data
			? (targetBranch.headCommit.snapshot.data as SnapshotData)
			: { shapes: [] };

		// Check for conflicts
		const mergeResult = performThreeWayMerge(
			baseSnapshot,
			sourceSnapshot,
			targetSnapshot,
		);

		if (!mergeResult.success) {
			throw new ServerError(
				Status.FAILED_PRECONDITION,
				`Merge has ${mergeResult.conflicts.length} conflict(s) that must be resolved`,
			);
		}

		// Perform merge based on strategy
		if (isFastForward) {
			await performFastForward(pr.targetBranchId, sourceBranch.headCommitId);
			wasFastForward = true;
		} else {
			// Create merge commit
			const mergeMessage =
				commitMessage ||
				`Merge pull request: ${pr.title}\n\nMerge '${sourceBranch.name}' into '${targetBranch.name}'`;

			mergeCommit = await createMergeCommit(
				projectId,
				pr.targetBranchId,
				mergeResult.mergedShapes,
				mergedById,
				mergeMessage,
			);
		}

		// Update PR status
		const now = new Date();
		await db
			.update(schema.pullRequests)
			.set({
				status: "merged",
				mergedAt: now,
				updatedAt: now,
			})
			.where(eq(schema.pullRequests.id, pullRequestId));

		// Get updated PR
		const updatedPR = await db.query.pullRequests.findFirst({
			where: eq(schema.pullRequests.id, pullRequestId),
		});

		if (!updatedPR) {
			throw new ServerError(
				Status.INTERNAL,
				"Pull request not found after update",
			);
		}

		return {
			pullRequest: toProtoPullRequest(updatedPR),
			mergeCommit: mergeCommit ? toProtoCommit(mergeCommit) : undefined,
		};
	},

	async closePullRequest(req): Promise<ClosePullRequestResponse> {
		const { projectId, pullRequestId } = req;

		const pr = await db.query.pullRequests.findFirst({
			where: and(
				eq(schema.pullRequests.id, pullRequestId),
				eq(schema.pullRequests.projectId, projectId),
			),
		});

		if (!pr) {
			throw new ServerError(Status.NOT_FOUND, "Pull request not found");
		}

		if (pr.status !== "open") {
			throw new ServerError(
				Status.FAILED_PRECONDITION,
				"Pull request is not open",
			);
		}

		const now = new Date();
		const [updated] = await db
			.update(schema.pullRequests)
			.set({
				status: "closed",
				closedAt: now,
				updatedAt: now,
			})
			.where(eq(schema.pullRequests.id, pullRequestId))
			.returning();

		return {
			pullRequest: toProtoPullRequest(updated),
		};
	},

	async reopenPullRequest(req): Promise<ReopenPullRequestResponse> {
		const { projectId, pullRequestId } = req;

		const pr = await db.query.pullRequests.findFirst({
			where: and(
				eq(schema.pullRequests.id, pullRequestId),
				eq(schema.pullRequests.projectId, projectId),
			),
		});

		if (!pr) {
			throw new ServerError(Status.NOT_FOUND, "Pull request not found");
		}

		if (pr.status === "merged") {
			throw new ServerError(
				Status.FAILED_PRECONDITION,
				"Cannot reopen a merged pull request",
			);
		}

		if (pr.status === "open") {
			throw new ServerError(
				Status.FAILED_PRECONDITION,
				"Pull request is already open",
			);
		}

		const [updated] = await db
			.update(schema.pullRequests)
			.set({
				status: "open",
				closedAt: null,
				updatedAt: new Date(),
			})
			.where(eq(schema.pullRequests.id, pullRequestId))
			.returning();

		return {
			pullRequest: toProtoPullRequest(updated),
		};
	},

	async checkMergeStatus(req): Promise<CheckMergeStatusResponse> {
		const { projectId, pullRequestId } = req;

		const pr = await db.query.pullRequests.findFirst({
			where: and(
				eq(schema.pullRequests.id, pullRequestId),
				eq(schema.pullRequests.projectId, projectId),
			),
		});

		if (!pr) {
			throw new ServerError(Status.NOT_FOUND, "Pull request not found");
		}

		// Count commits ahead/behind
		const { ahead, behind } = await countCommitsDivergence(
			pr.sourceBranchId,
			pr.targetBranchId,
		);

		if (pr.status !== "open") {
			return {
				mergeable: false,
				reason:
					pr.status === "merged"
						? "Pull request is already merged"
						: "Pull request is closed",
				conflicts: [],
				commitsAhead: ahead,
				commitsBehind: behind,
			};
		}

		// Get branches with snapshots
		const sourceBranch = await db.query.branches.findFirst({
			where: eq(schema.branches.id, pr.sourceBranchId),
			with: { headCommit: { with: { snapshot: true } } },
		});

		const targetBranch = await db.query.branches.findFirst({
			where: eq(schema.branches.id, pr.targetBranchId),
			with: { headCommit: { with: { snapshot: true } } },
		});

		if (!sourceBranch || !targetBranch) {
			return {
				mergeable: false,
				reason: "Source or target branch not found",
				conflicts: [],
				commitsAhead: ahead,
				commitsBehind: behind,
			};
		}

		// Get snapshots and check for conflicts
		const commonAncestor = await findCommonAncestor(
			pr.sourceBranchId,
			pr.targetBranchId,
		);

		const baseSnapshot = commonAncestor?.snapshotId
			? await getSnapshotData(commonAncestor.snapshotId)
			: null;

		interface SnapshotData {
			shapes: SnapshotShape[];
		}

		const sourceSnapshot = sourceBranch.headCommit?.snapshot?.data
			? (sourceBranch.headCommit.snapshot.data as SnapshotData)
			: { shapes: [] };

		const targetSnapshot = targetBranch.headCommit?.snapshot?.data
			? (targetBranch.headCommit.snapshot.data as SnapshotData)
			: { shapes: [] };

		const mergeResult = performThreeWayMerge(
			baseSnapshot,
			sourceSnapshot,
			targetSnapshot,
		);

		if (mergeResult.success) {
			return {
				mergeable: true,
				conflicts: [],
				commitsAhead: ahead,
				commitsBehind: behind,
			};
		}

		return {
			mergeable: false,
			reason: `Has ${mergeResult.conflicts.length} conflict(s) that need resolution`,
			conflicts: mergeResult.conflicts,
			commitsAhead: ahead,
			commitsBehind: behind,
		};
	},

	async resolveConflicts(req): Promise<ResolveConflictsResponse> {
		const { projectId, pullRequestId, resolutions, resolvedById } = req;

		const pr = await db.query.pullRequests.findFirst({
			where: and(
				eq(schema.pullRequests.id, pullRequestId),
				eq(schema.pullRequests.projectId, projectId),
			),
		});

		if (!pr) {
			throw new ServerError(Status.NOT_FOUND, "Pull request not found");
		}

		if (pr.status !== "open") {
			throw new ServerError(
				Status.FAILED_PRECONDITION,
				"Pull request is not open",
			);
		}

		// Get branches with snapshots
		const sourceBranch = await db.query.branches.findFirst({
			where: eq(schema.branches.id, pr.sourceBranchId),
			with: { headCommit: { with: { snapshot: true } } },
		});

		const targetBranch = await db.query.branches.findFirst({
			where: eq(schema.branches.id, pr.targetBranchId),
			with: { headCommit: { with: { snapshot: true } } },
		});

		if (!sourceBranch || !targetBranch) {
			throw new ServerError(Status.INTERNAL, "Branch not found");
		}

		// Get snapshots
		const commonAncestor = await findCommonAncestor(
			pr.sourceBranchId,
			pr.targetBranchId,
		);

		const baseSnapshot = commonAncestor?.snapshotId
			? await getSnapshotData(commonAncestor.snapshotId)
			: null;

		interface SnapshotData {
			shapes: SnapshotShape[];
		}

		const sourceSnapshot = sourceBranch.headCommit?.snapshot?.data
			? (sourceBranch.headCommit.snapshot.data as SnapshotData)
			: { shapes: [] };

		const targetSnapshot = targetBranch.headCommit?.snapshot?.data
			? (targetBranch.headCommit.snapshot.data as SnapshotData)
			: { shapes: [] };

		// Perform merge to get base merged result
		const mergeResult = performThreeWayMerge(
			baseSnapshot,
			sourceSnapshot,
			targetSnapshot,
		);

		// Apply conflict resolutions
		const resolutionMap = new Map(
			resolutions.map((r) => [`${r.shapeId}:${r.propertyName}`, r]),
		);

		const resolvedShapes = mergeResult.mergedShapes.map((shape) => {
			const updatedShape = { ...shape };

			// Find conflicts for this shape
			const shapeConflicts = mergeResult.conflicts.find(
				(c) => c.shapeId === shape.id,
			);

			if (shapeConflicts) {
				for (const propConflict of shapeConflicts.propertyConflicts) {
					const resolution = resolutionMap.get(
						`${shape.id}:${propConflict.propertyName}`,
					);

					if (resolution) {
						// Apply resolution based on choice
						// For now, customValue takes precedence, otherwise use source/target based on choice
						if (resolution.customValue) {
							try {
								updatedShape[propConflict.propertyName] = JSON.parse(
									resolution.customValue,
								);
							} catch {
								updatedShape[propConflict.propertyName] =
									resolution.customValue;
							}
						} else if (resolution.choice === 0) {
							// SOURCE
							try {
								updatedShape[propConflict.propertyName] = JSON.parse(
									propConflict.sourceValue,
								);
							} catch {
								updatedShape[propConflict.propertyName] =
									propConflict.sourceValue;
							}
						} else {
							// TARGET (default)
							try {
								updatedShape[propConflict.propertyName] = JSON.parse(
									propConflict.targetValue,
								);
							} catch {
								updatedShape[propConflict.propertyName] =
									propConflict.targetValue;
							}
						}
					}
				}
			}

			return updatedShape;
		});

		// Create a resolution commit on the source branch
		const [newSnapshot] = await db
			.insert(schema.snapshots)
			.values({
				projectId,
				data: { shapes: resolvedShapes, version: 1 },
			})
			.returning();

		const [resolutionCommit] = await db
			.insert(schema.commits)
			.values({
				projectId,
				branchId: pr.sourceBranchId,
				parentId: sourceBranch.headCommitId,
				message: `Resolve merge conflicts for PR: ${pr.title}`,
				authorId: resolvedById,
				snapshotId: newSnapshot.id,
			})
			.returning();

		// Update source branch head
		await db
			.update(schema.branches)
			.set({
				headCommitId: resolutionCommit.id,
				updatedAt: new Date(),
			})
			.where(eq(schema.branches.id, pr.sourceBranchId));

		// Update PR
		await db
			.update(schema.pullRequests)
			.set({ updatedAt: new Date() })
			.where(eq(schema.pullRequests.id, pullRequestId));

		// Get updated PR
		const updatedPR = await db.query.pullRequests.findFirst({
			where: eq(schema.pullRequests.id, pullRequestId),
		});

		if (!updatedPR) {
			throw new ServerError(
				Status.INTERNAL,
				"Pull request not found after update",
			);
		}

		// Check if there are any remaining unresolved conflicts
		const resolvedShapeIds = new Set(resolutions.map((r) => r.shapeId));
		const remainingConflicts = mergeResult.conflicts.filter((c) => {
			// Check if all property conflicts for this shape are resolved
			const allResolved = c.propertyConflicts.every((pc) =>
				resolutionMap.has(`${c.shapeId}:${pc.propertyName}`),
			);
			return !allResolved;
		});

		return {
			pullRequest: toProtoPullRequest(updatedPR),
			remainingConflicts,
			mergeable: remainingConflicts.length === 0,
		};
	},
};
