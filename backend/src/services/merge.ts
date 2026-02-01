/**
 * Merge Utilities
 *
 * Property-level three-way merge for design shapes.
 *
 * Algorithm (Option B - Property-level merge):
 * 1. Find common ancestor snapshot of source and target branches
 * 2. For each shape, compare properties between base, source, and target
 * 3. Non-conflicting changes are auto-merged (one side changed, other didn't)
 * 4. Conflicting changes (both sides changed same property) require resolution
 *
 * Reference: gitea/services/pull/merge.go for merge workflow patterns
 */

import { eq } from "drizzle-orm";
import { db, schema } from "../db";
import type { DiffResult } from "../gen/vio/v1/commit.js";
import type {
	PropertyConflict,
	ShapeConflict,
	Timestamp,
} from "../gen/vio/v1/common.js";

// Type alias for commit records from database
type CommitRecord = typeof schema.commits.$inferSelect;

// Shape JSON structure in snapshots
export interface SnapshotShape {
	id: string;
	name: string;
	type: string;
	[key: string]: unknown;
}

export interface SnapshotData {
	shapes: SnapshotShape[];
	version?: number;
}

// Merge result types
export interface MergeResult {
	success: boolean;
	conflicts: ShapeConflict[];
	mergedShapes: SnapshotShape[];
	diff: DiffResult;
}

export interface ThreeWayMergeContext {
	baseShapes: Map<string, SnapshotShape>;
	sourceShapes: Map<string, SnapshotShape>;
	targetShapes: Map<string, SnapshotShape>;
}

/**
 * Parse snapshot data from binary JSONB
 */
export function parseSnapshotData(data: unknown): SnapshotData {
	if (typeof data === "string") {
		return JSON.parse(data) as SnapshotData;
	}
	if (Buffer.isBuffer(data)) {
		return JSON.parse(data.toString("utf-8")) as SnapshotData;
	}
	return data as SnapshotData;
}

/**
 * Build a map of shapes by ID for efficient lookup
 */
function buildShapeMap(shapes: SnapshotShape[]): Map<string, SnapshotShape> {
	const map = new Map<string, SnapshotShape>();
	for (const shape of shapes) {
		map.set(shape.id, shape);
	}
	return map;
}

/**
 * Find the common ancestor commit between two branches.
 *
 * Simple algorithm: walk back from both heads until we find a shared commit.
 * For more complex history, this would need a proper DAG traversal.
 */
export async function findCommonAncestor(
	sourceBranchId: string,
	targetBranchId: string,
): Promise<typeof schema.commits.$inferSelect | null> {
	// Get branch heads
	const sourceBranch = await db.query.branches.findFirst({
		where: eq(schema.branches.id, sourceBranchId),
	});

	const targetBranch = await db.query.branches.findFirst({
		where: eq(schema.branches.id, targetBranchId),
	});

	if (!sourceBranch?.headCommitId || !targetBranch?.headCommitId) {
		return null;
	}

	// Build set of all commits in source branch history
	const sourceCommits = new Set<string>();
	let currentId: string | null = sourceBranch.headCommitId;

	while (currentId) {
		sourceCommits.add(currentId);
		const commit: CommitRecord | undefined = await db.query.commits.findFirst({
			where: eq(schema.commits.id, currentId),
		});
		currentId = commit?.parentId ?? null;
	}

	// Walk target branch history until we find a commit in source history
	currentId = targetBranch.headCommitId;

	while (currentId) {
		if (sourceCommits.has(currentId)) {
			const result = await db.query.commits.findFirst({
				where: eq(schema.commits.id, currentId),
			});
			return result ?? null;
		}
		const commit: CommitRecord | undefined = await db.query.commits.findFirst({
			where: eq(schema.commits.id, currentId),
		});
		currentId = commit?.parentId ?? null;
	}

	return null;
}

/**
 * Get snapshot data for a commit
 */
export async function getSnapshotData(
	snapshotId: string,
): Promise<SnapshotData | null> {
	const snapshot = await db.query.snapshots.findFirst({
		where: eq(schema.snapshots.id, snapshotId),
	});

	if (!snapshot) {
		return null;
	}

	return parseSnapshotData(snapshot.data);
}

/**
 * Calculate diff between two snapshots
 */
export function calculateDiff(
	sourceShapes: Map<string, SnapshotShape>,
	targetShapes: Map<string, SnapshotShape>,
): DiffResult {
	const addedShapeIds: string[] = [];
	const removedShapeIds: string[] = [];
	const modifiedShapeIds: string[] = [];

	// Find added and modified shapes (in target but not source, or different)
	for (const [id, targetShape] of targetShapes) {
		const sourceShape = sourceShapes.get(id);
		if (!sourceShape) {
			addedShapeIds.push(id);
		} else if (JSON.stringify(sourceShape) !== JSON.stringify(targetShape)) {
			modifiedShapeIds.push(id);
		}
	}

	// Find removed shapes (in source but not target)
	for (const id of sourceShapes.keys()) {
		if (!targetShapes.has(id)) {
			removedShapeIds.push(id);
		}
	}

	return {
		addedShapeIds,
		removedShapeIds,
		modifiedShapeIds,
	};
}

/**
 * Compare a specific property across three versions
 */
function compareProperty(
	propertyName: string,
	baseValue: unknown,
	sourceValue: unknown,
	targetValue: unknown,
): PropertyConflict | null {
	const baseStr = JSON.stringify(baseValue);
	const sourceStr = JSON.stringify(sourceValue);
	const targetStr = JSON.stringify(targetValue);

	const sourceChanged = baseStr !== sourceStr;
	const targetChanged = baseStr !== targetStr;

	// No conflict if only one side changed
	if (!sourceChanged || !targetChanged) {
		return null;
	}

	// No conflict if both sides made the same change
	if (sourceStr === targetStr) {
		return null;
	}

	// Conflict: both sides changed the same property differently
	return {
		propertyName,
		baseValue: baseStr,
		sourceValue: sourceStr,
		targetValue: targetStr,
	};
}

/**
 * Perform three-way merge of a single shape's properties.
 *
 * Option B strategy: Merge non-conflicting properties automatically.
 * Returns the merged shape and any conflicts that need manual resolution.
 */
function mergeShapeProperties(
	shapeId: string,
	baseShape: SnapshotShape | undefined,
	sourceShape: SnapshotShape | undefined,
	targetShape: SnapshotShape | undefined,
): { mergedShape: SnapshotShape | null; conflicts: PropertyConflict[] } {
	// Handle deletion cases
	if (!sourceShape && !targetShape) {
		return { mergedShape: null, conflicts: [] };
	}

	// If shape doesn't exist in base, it was added
	if (!baseShape) {
		// Both branches added a shape with the same ID - use target (ours) by default
		// This is rare but possible with UUID collisions or intentional same IDs
		return {
			mergedShape: targetShape || sourceShape || null,
			conflicts: [],
		};
	}

	// If deleted in source but exists in target
	if (!sourceShape && targetShape) {
		// Check if target modified it - if so, conflict
		if (JSON.stringify(baseShape) !== JSON.stringify(targetShape)) {
			// Target modified, source deleted - keep target's version
			// This could be a conflict in strict mode, but we auto-resolve
			return { mergedShape: targetShape, conflicts: [] };
		}
		// Target didn't modify, source deleted - accept deletion
		return { mergedShape: null, conflicts: [] };
	}

	// If deleted in target but exists in source
	if (sourceShape && !targetShape) {
		// Check if source modified it
		if (JSON.stringify(baseShape) !== JSON.stringify(sourceShape)) {
			// Source modified, target deleted - could be conflict
			// For now, accept the deletion (target's intent)
			return { mergedShape: null, conflicts: [] };
		}
		// Source didn't modify, target deleted - accept deletion
		return { mergedShape: null, conflicts: [] };
	}

	// Both shapes exist - merge properties
	const mergedShape: SnapshotShape = {
		id: shapeId,
		name: baseShape.name,
		type: baseShape.type,
	};
	const conflicts: PropertyConflict[] = [];

	// Get all property keys from all three versions
	// At this point we know both sourceShape and targetShape exist
	const source = sourceShape as SnapshotShape;
	const target = targetShape as SnapshotShape;

	const allKeys = new Set([
		...Object.keys(baseShape),
		...Object.keys(source),
		...Object.keys(target),
	]);

	for (const key of allKeys) {
		if (key === "id") {
			mergedShape.id = shapeId;
			continue;
		}

		const baseValue = baseShape[key];
		const sourceValue = source[key];
		const targetValue = target[key];

		const conflict = compareProperty(key, baseValue, sourceValue, targetValue);

		if (conflict) {
			conflicts.push(conflict);
			// For conflicts, temporarily use target value (can be resolved later)
			mergedShape[key] = targetValue;
		} else {
			// No conflict - use whichever side changed, or keep base if neither
			const sourceChanged =
				JSON.stringify(baseValue) !== JSON.stringify(sourceValue);
			const targetChanged =
				JSON.stringify(baseValue) !== JSON.stringify(targetValue);

			if (sourceChanged) {
				mergedShape[key] = sourceValue;
			} else if (targetChanged) {
				mergedShape[key] = targetValue;
			} else {
				mergedShape[key] = baseValue;
			}
		}
	}

	return { mergedShape, conflicts };
}

/**
 * Perform a full three-way merge between source and target branches.
 *
 * @param baseSnapshot - Common ancestor state
 * @param sourceSnapshot - Source branch (incoming changes)
 * @param targetSnapshot - Target branch (current state)
 * @returns Merge result with merged shapes and any conflicts
 */
export function performThreeWayMerge(
	baseSnapshot: SnapshotData | null,
	sourceSnapshot: SnapshotData,
	targetSnapshot: SnapshotData,
): MergeResult {
	const baseShapes = buildShapeMap(baseSnapshot?.shapes ?? []);
	const sourceShapes = buildShapeMap(sourceSnapshot.shapes);
	const targetShapes = buildShapeMap(targetSnapshot.shapes);

	const allShapeIds = new Set([
		...baseShapes.keys(),
		...sourceShapes.keys(),
		...targetShapes.keys(),
	]);

	const mergedShapes: SnapshotShape[] = [];
	const allConflicts: ShapeConflict[] = [];

	for (const shapeId of allShapeIds) {
		const baseShape = baseShapes.get(shapeId);
		const sourceShape = sourceShapes.get(shapeId);
		const targetShape = targetShapes.get(shapeId);

		const { mergedShape, conflicts } = mergeShapeProperties(
			shapeId,
			baseShape,
			sourceShape,
			targetShape,
		);

		if (mergedShape) {
			mergedShapes.push(mergedShape);
		}

		if (conflicts.length > 0) {
			allConflicts.push({
				shapeId,
				shapeName: mergedShape?.name ?? baseShape?.name ?? "Unknown",
				shapeType: mergedShape?.type ?? baseShape?.type ?? "unknown",
				propertyConflicts: conflicts,
			});
		}
	}

	// Calculate diff from target (current) to merged result
	const diff = calculateDiff(targetShapes, buildShapeMap(mergedShapes));

	return {
		success: allConflicts.length === 0,
		conflicts: allConflicts,
		mergedShapes,
		diff,
	};
}

/**
 * Check if fast-forward merge is possible.
 *
 * Fast-forward is possible when target branch's head is an ancestor of source.
 */
export async function canFastForward(
	sourceBranchId: string,
	targetBranchId: string,
): Promise<boolean> {
	const sourceBranch = await db.query.branches.findFirst({
		where: eq(schema.branches.id, sourceBranchId),
	});

	const targetBranch = await db.query.branches.findFirst({
		where: eq(schema.branches.id, targetBranchId),
	});

	if (!sourceBranch?.headCommitId) {
		return false;
	}

	if (!targetBranch?.headCommitId) {
		// Target has no commits - can fast-forward
		return true;
	}

	// Walk source history to see if target head is an ancestor
	let currentId: string | null = sourceBranch.headCommitId;

	while (currentId) {
		if (currentId === targetBranch.headCommitId) {
			return true;
		}
		const commit: CommitRecord | undefined = await db.query.commits.findFirst({
			where: eq(schema.commits.id, currentId),
		});
		currentId = commit?.parentId ?? null;
	}

	return false;
}

/**
 * Count commits ahead/behind between branches
 */
export async function countCommitsDivergence(
	sourceBranchId: string,
	targetBranchId: string,
): Promise<{ ahead: number; behind: number }> {
	const ancestor = await findCommonAncestor(sourceBranchId, targetBranchId);

	const sourceBranch = await db.query.branches.findFirst({
		where: eq(schema.branches.id, sourceBranchId),
	});

	const targetBranch = await db.query.branches.findFirst({
		where: eq(schema.branches.id, targetBranchId),
	});

	let ahead = 0;
	let behind = 0;

	// Count commits in source not in target (ahead)
	let currentId: string | null = sourceBranch?.headCommitId ?? null;
	while (currentId && currentId !== ancestor?.id) {
		ahead++;
		const commit: CommitRecord | undefined = await db.query.commits.findFirst({
			where: eq(schema.commits.id, currentId),
		});
		currentId = commit?.parentId ?? null;
	}

	// Count commits in target not in source (behind)
	currentId = targetBranch?.headCommitId ?? null;
	while (currentId && currentId !== ancestor?.id) {
		behind++;
		const commit: CommitRecord | undefined = await db.query.commits.findFirst({
			where: eq(schema.commits.id, currentId),
		});
		currentId = commit?.parentId ?? null;
	}

	return { ahead, behind };
}

/**
 * Create a merge commit with merged snapshot
 */
export async function createMergeCommit(
	projectId: string,
	targetBranchId: string,
	mergedShapes: SnapshotShape[],
	authorId: string,
	message: string,
): Promise<typeof schema.commits.$inferSelect> {
	// Get current target branch head as parent
	const targetBranch = await db.query.branches.findFirst({
		where: eq(schema.branches.id, targetBranchId),
	});

	// Create snapshot with merged data
	const snapshotData: SnapshotData = {
		shapes: mergedShapes,
		version: 1,
	};

	const [snapshot] = await db
		.insert(schema.snapshots)
		.values({
			projectId,
			data: snapshotData,
		})
		.returning();

	// Create merge commit
	const [commit] = await db
		.insert(schema.commits)
		.values({
			projectId,
			branchId: targetBranchId,
			parentId: targetBranch?.headCommitId ?? null,
			message,
			authorId,
			snapshotId: snapshot.id,
		})
		.returning();

	// Update target branch head
	await db
		.update(schema.branches)
		.set({
			headCommitId: commit.id,
			updatedAt: new Date(),
		})
		.where(eq(schema.branches.id, targetBranchId));

	return commit;
}

/**
 * Perform fast-forward merge by updating branch pointer
 */
export async function performFastForward(
	targetBranchId: string,
	sourceCommitId: string,
): Promise<void> {
	await db
		.update(schema.branches)
		.set({
			headCommitId: sourceCommitId,
			updatedAt: new Date(),
		})
		.where(eq(schema.branches.id, targetBranchId));
}

// Helper to convert DB timestamp to proto Timestamp
export function toProtoTimestamp(date: Date): Timestamp {
	return {
		millis: BigInt(date.getTime()),
	};
}
