/**
 * Integration tests for branch switching with version control.
 *
 * Tests the complete flow:
 * 1. Create project and branch
 * 2. Make changes (add shapes)
 * 3. Commit changes
 * 4. Switch branches
 * 5. Verify shapes are correctly loaded from the target branch's snapshot
 */

import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { eq } from "drizzle-orm";
import type { CallContext } from "nice-grpc";
import { db, schema } from "../db";
import { branchServiceImpl } from "../services/branch";
import { canvasServiceImpl } from "../services/canvas";
import { commitServiceImpl } from "../services/commit";

// Mock CallContext for testing gRPC service implementations directly
const mockContext = {} as CallContext;

describe("Branch Switch Integration", () => {
	let projectId: string;
	let mainBranchId: string;
	let featureBranchId: string;
	// Use a proper UUID for the test user
	const userId = "00000000-0000-0000-0000-000000000099";

	beforeAll(async () => {
		// Create a test project
		const [project] = await db
			.insert(schema.projects)
			.values({
				name: "Test Project for Branch Switch",
				ownerId: userId,
			})
			.returning();
		projectId = project.id;

		// Create main branch
		const mainBranchResponse = await branchServiceImpl.createBranch(
			{
				projectId,
				name: "main",
				createdById: userId,
			},
			mockContext,
		);
		mainBranchId = mainBranchResponse.branch!.id;

		// Set as default branch
		await db
			.update(schema.projects)
			.set({ defaultBranchId: mainBranchId })
			.where(eq(schema.projects.id, projectId));
	});

	afterAll(async () => {
		// Cleanup: delete project and all related data
		if (projectId) {
			await db
				.delete(schema.shapes)
				.where(eq(schema.shapes.projectId, projectId));
			await db
				.delete(schema.commits)
				.where(eq(schema.commits.projectId, projectId));
			await db
				.delete(schema.snapshots)
				.where(eq(schema.snapshots.projectId, projectId));
			await db
				.delete(schema.branches)
				.where(eq(schema.branches.projectId, projectId));
			await db.delete(schema.projects).where(eq(schema.projects.id, projectId));
		}
	});

	it("should preserve shapes after branch switch round-trip", async () => {
		// Step 1: Add shapes to the working copy (shapes table)
		const shape1Id = crypto.randomUUID();
		const shape2Id = crypto.randomUUID();

		await db.insert(schema.shapes).values([
			{
				id: shape1Id,
				projectId,
				type: "rectangle",
				name: "Rectangle 1",
				x: 100,
				y: 100,
				width: 200,
				height: 150,
			},
			{
				id: shape2Id,
				projectId,
				type: "ellipse",
				name: "Circle 1",
				x: 400,
				y: 300,
				width: 100,
				height: 100,
			},
		]);

		// Step 2: Create first commit on main branch
		const commit1Response = await commitServiceImpl.createCommit(
			{
				projectId,
				branchId: mainBranchId,
				message: "Add two shapes on main",
				authorId: userId,
				snapshotData: new Uint8Array(), // Not used - server creates snapshot from DB shapes
			},
			mockContext,
		);
		expect(commit1Response.commit?.id).toBeDefined();
		const mainCommitId = commit1Response.commit!.id;

		// Step 3: Create feature branch from main
		const featureBranchResponse = await branchServiceImpl.createBranch(
			{
				projectId,
				name: "feature/new-shapes",
				sourceBranchId: mainBranchId,
				createdById: userId,
			},
			mockContext,
		);
		featureBranchId = featureBranchResponse.branch!.id;

		// Feature branch should have the same head commit as main (branched from it)
		expect(featureBranchResponse.branch!.headCommitId).toBe(mainCommitId);

		// Step 4: Switch to feature branch (restore from its snapshot)
		const featureBranch = await db.query.branches.findFirst({
			where: eq(schema.branches.id, featureBranchId),
		});
		expect(featureBranch?.headCommitId).toBe(mainCommitId);

		// Fetch the commit's snapshot
		const featureCommit = await db.query.commits.findFirst({
			where: eq(schema.commits.id, featureBranch!.headCommitId!),
		});
		expect(featureCommit?.snapshotId).toBeDefined();

		// Restore working copy from feature branch's snapshot
		const restoreResponse = await canvasServiceImpl.restoreFromSnapshot(
			{
				projectId,
				snapshotId: featureCommit!.snapshotId,
			},
			mockContext,
		);
		expect(restoreResponse.success).toBe(true);
		expect(restoreResponse.shapeCount).toBe(2);

		// Step 5: Modify shapes on feature branch - add a new shape
		const shape3Id = crypto.randomUUID();
		await db.insert(schema.shapes).values({
			id: shape3Id,
			projectId,
			type: "rectangle",
			name: "Feature Rectangle",
			x: 600,
			y: 100,
			width: 150,
			height: 150,
		});

		// Step 6: Commit on feature branch
		const commit2Response = await commitServiceImpl.createCommit(
			{
				projectId,
				branchId: featureBranchId,
				message: "Add feature rectangle",
				authorId: userId,
				snapshotData: new Uint8Array(), // Not used - server creates snapshot from DB shapes
			},
			mockContext,
		);
		expect(commit2Response.commit?.id).toBeDefined();
		const featureCommitId = commit2Response.commit!.id;

		// Step 7: Switch back to main (should only have 2 shapes)
		const mainBranch = await db.query.branches.findFirst({
			where: eq(schema.branches.id, mainBranchId),
		});
		const mainCommit = await db.query.commits.findFirst({
			where: eq(schema.commits.id, mainBranch!.headCommitId!),
		});

		const restoreMainResponse = await canvasServiceImpl.restoreFromSnapshot(
			{
				projectId,
				snapshotId: mainCommit!.snapshotId,
			},
			mockContext,
		);
		expect(restoreMainResponse.success).toBe(true);
		expect(restoreMainResponse.shapeCount).toBe(2);

		// Verify shapes in DB match main branch's state
		const shapesAfterMainSwitch = await db
			.select()
			.from(schema.shapes)
			.where(eq(schema.shapes.projectId, projectId));
		expect(shapesAfterMainSwitch.length).toBe(2);
		expect(shapesAfterMainSwitch.map((s) => s.id).sort()).toEqual(
			[shape1Id, shape2Id].sort(),
		);

		// Step 8: getCanvasState should return main branch's shapes (from snapshot)
		const canvasState = await canvasServiceImpl.getCanvasState(
			{
				projectId,
				branchId: mainBranchId,
			},
			mockContext,
		);
		expect(canvasState.state?.shapes.length).toBe(2);

		// Step 9: Switch back to feature - should have 3 shapes
		const updatedFeatureBranch = await db.query.branches.findFirst({
			where: eq(schema.branches.id, featureBranchId),
		});
		const updatedFeatureCommit = await db.query.commits.findFirst({
			where: eq(schema.commits.id, updatedFeatureBranch!.headCommitId!),
		});

		const restoreFeatureResponse = await canvasServiceImpl.restoreFromSnapshot(
			{
				projectId,
				snapshotId: updatedFeatureCommit!.snapshotId,
			},
			mockContext,
		);
		expect(restoreFeatureResponse.success).toBe(true);
		expect(restoreFeatureResponse.shapeCount).toBe(3);

		// Verify shapes in DB match feature branch's state
		const shapesAfterFeatureSwitch = await db
			.select()
			.from(schema.shapes)
			.where(eq(schema.shapes.projectId, projectId));
		expect(shapesAfterFeatureSwitch.length).toBe(3);

		// Step 10: getCanvasState on feature branch should return 3 shapes
		const featureCanvasState = await canvasServiceImpl.getCanvasState(
			{
				projectId,
				branchId: featureBranchId,
			},
			mockContext,
		);
		expect(featureCanvasState.state?.shapes.length).toBe(3);
	});

	it("should return empty shapes for branch with no commits", async () => {
		// Create an empty branch (no source, no commits)
		const emptyBranchResponse = await branchServiceImpl.createBranch(
			{
				projectId,
				name: "empty-branch",
				createdById: userId,
			},
			mockContext,
		);
		const emptyBranchId = emptyBranchResponse.branch!.id;

		// getCanvasState should return empty shapes
		const canvasState = await canvasServiceImpl.getCanvasState(
			{
				projectId,
				branchId: emptyBranchId,
			},
			mockContext,
		);
		expect(canvasState.state?.shapes.length).toBe(0);
	});
});
