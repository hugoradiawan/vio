/**
 * Seed script to create demo and stress-test projects.
 *
 * Commands:
 * - Default demo seed: bun run db:seed
 * - Stress levels:      bun run db:seed:stress:small|medium|large
 */

import { eq } from "drizzle-orm";
import { randomUUID } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import sharp from "sharp";
import { db, schema } from "./index";

const DEMO_PROJECT_ID = "00000000-0000-0000-0000-000000000001";
const DEMO_BRANCH_ID = "00000000-0000-0000-0000-000000000002";
const DEMO_USER_ID = "00000000-0000-0000-0000-000000000099";
const DEMO_FRAME_ID = "00000000-0000-0000-0000-000000000010";
const DEMO_COMMIT_ID = "00000000-0000-0000-0000-000000000003";
const DEMO_SNAPSHOT_ID = "00000000-0000-0000-0000-000000000004";

const SHAPE_FRAME_ID = "00000000-0000-0000-0001-000000000001";
const SHAPE_RECT_1_ID = "00000000-0000-0000-0001-000000000002";
const SHAPE_RECT_2_ID = "00000000-0000-0000-0001-000000000003";
const SHAPE_ELLIPSE_1_ID = "00000000-0000-0000-0001-000000000004";
const SHAPE_RECT_3_ID = "00000000-0000-0000-0001-000000000005";
const SHAPE_ELLIPSE_2_ID = "00000000-0000-0000-0001-000000000006";

const STRESS_PROJECT_IDS = {
	small: "11111111-0000-0000-0000-000000000001",
	medium: "11111111-0000-0000-0000-000000000002",
	large: "11111111-0000-0000-0000-000000000003",
} as const;

const STRESS_IMAGES_DIR = path.resolve(import.meta.dir, "../../../images");
const SUPPORTED_IMAGE_EXTENSIONS = new Set([
	".jpg",
	".jpeg",
	".png",
	".gif",
	".webp",
	".svg",
]);

interface StressConfig {
	level: StressLevel;
	projectName: string;
	projectId: string;
	frameCount: number;
	shapesPerFrame: number;
	assetCount: number;
	branchCount: number;
	commitsPerBranch: number;
}

type StressLevel = "small" | "medium" | "large";

interface ImageSource {
	name: string;
	mimeType: string;
	data: Buffer;
	thumbnail: Buffer | null;
	width: number;
	height: number;
}

interface SeedAsset {
	id: string;
	name: string;
	width: number;
	height: number;
}

function parseStressLevelArg(): StressLevel | null {
	const arg = process.argv.find((item) => item.startsWith("--stress-level="));
	if (!arg) return null;

	const value = arg.split("=")[1]?.toLowerCase();
	if (value === "small" || value === "medium" || value === "large") {
		return value;
	}

	throw new Error(
		`Invalid --stress-level value: ${value}. Use small, medium, or large.`,
	);
}

function createStressConfig(level: StressLevel): StressConfig {
	if (level === "small") {
		return {
			level,
			projectName: "Stress Test - Small",
			projectId: STRESS_PROJECT_IDS.small,
			frameCount: 12,
			shapesPerFrame: 180,
			assetCount: 30,
			branchCount: 2,
			commitsPerBranch: 12,
		};
	}

	if (level === "medium") {
		return {
			level,
			projectName: "Stress Test - Medium",
			projectId: STRESS_PROJECT_IDS.medium,
			frameCount: 36,
			shapesPerFrame: 240,
			assetCount: 100,
			branchCount: 3,
			commitsPerBranch: 18,
		};
	}

	return {
		level,
		projectName: "Stress Test - Large",
		projectId: STRESS_PROJECT_IDS.large,
		frameCount: 96,
		shapesPerFrame: 300,
		assetCount: 300,
		branchCount: 5,
		commitsPerBranch: 24,
	};
}

async function insertInBatches<T>(
	rows: T[],
	batchSize: number,
	inserter: (batch: T[]) => Promise<void>,
): Promise<void> {
	for (let index = 0; index < rows.length; index += batchSize) {
		const batch = rows.slice(index, index + batchSize);
		await inserter(batch);
	}
}

function extToMime(ext: string): string {
	switch (ext.toLowerCase()) {
		case ".png":
			return "image/png";
		case ".jpg":
		case ".jpeg":
			return "image/jpeg";
		case ".gif":
			return "image/gif";
		case ".webp":
			return "image/webp";
		case ".svg":
			return "image/svg+xml";
		default:
			return "application/octet-stream";
	}
}

async function loadImageSources(): Promise<ImageSource[]> {
	const files = await readdir(STRESS_IMAGES_DIR);
	const imageFiles = files
		.filter((file) =>
			SUPPORTED_IMAGE_EXTENSIONS.has(path.extname(file).toLowerCase()),
		)
		.sort((left, right) => left.localeCompare(right));

	if (imageFiles.length === 0) {
		throw new Error(`No supported image files found in ${STRESS_IMAGES_DIR}`);
	}

	const sources: ImageSource[] = [];

	for (const file of imageFiles) {
		const filePath = path.join(STRESS_IMAGES_DIR, file);
		const data = await readFile(filePath);
		const mimeType = extToMime(path.extname(file));

		let width = 0;
		let height = 0;
		let thumbnail: Buffer | null = null;

		if (mimeType !== "image/svg+xml") {
			const metadata = await sharp(data).metadata();
			width = metadata.width ?? 0;
			height = metadata.height ?? 0;
			thumbnail = await sharp(data)
				.resize(256, 256, { fit: "inside", withoutEnlargement: true })
				.jpeg({ quality: 70 })
				.toBuffer();
		}

		sources.push({
			name: file,
			mimeType,
			data,
			thumbnail,
			width,
			height,
		});
	}

	return sources;
}

async function cleanupProject(projectId: string): Promise<void> {
	await db
		.delete(schema.commits)
		.where(eq(schema.commits.projectId, projectId));
	await db
		.delete(schema.snapshots)
		.where(eq(schema.snapshots.projectId, projectId));
	await db.delete(schema.shapes).where(eq(schema.shapes.projectId, projectId));
	await db.delete(schema.frames).where(eq(schema.frames.projectId, projectId));
	await db
		.delete(schema.projectAssets)
		.where(eq(schema.projectAssets.projectId, projectId));
	await db
		.delete(schema.projectColors)
		.where(eq(schema.projectColors.projectId, projectId));
	await db
		.delete(schema.branches)
		.where(eq(schema.branches.projectId, projectId));
	await db.delete(schema.projects).where(eq(schema.projects.id, projectId));
}

async function seedDemoProject(): Promise<void> {
	console.log("🌱 Seeding default demo project...");

	await cleanupProject(DEMO_PROJECT_ID);

	await db.insert(schema.projects).values({
		id: DEMO_PROJECT_ID,
		name: "Demo Project",
		description: "A demo project with test shapes for API testing",
		ownerId: DEMO_USER_ID,
		isPublic: true,
		defaultBranchId: DEMO_BRANCH_ID,
	});

	await db.insert(schema.branches).values({
		id: DEMO_BRANCH_ID,
		projectId: DEMO_PROJECT_ID,
		name: "main",
		description: "Main branch",
		isDefault: true,
		createdById: DEMO_USER_ID,
	});

	await db.insert(schema.frames).values({
		id: DEMO_FRAME_ID,
		projectId: DEMO_PROJECT_ID,
		name: "Frame 1",
		x: 0,
		y: 0,
		width: 800,
		height: 600,
		backgroundColor: "#2D2D2D",
	});

	const shapesData = [
		{
			id: SHAPE_FRAME_ID,
			projectId: DEMO_PROJECT_ID,
			frameId: null,
			parentId: null,
			type: "frame",
			name: "Frame 1",
			x: 0,
			y: 0,
			width: 800,
			height: 600,
			fills: [{ color: 0xff2d2d2d, opacity: 1.0 }],
			strokes: [{ color: 0xff404040 }],
			opacity: 1,
			hidden: false,
			blocked: false,
			rotation: 0,
			sortOrder: 0,
			properties: { clipContent: true },
		},
		{
			id: SHAPE_RECT_1_ID,
			projectId: DEMO_PROJECT_ID,
			frameId: null,
			parentId: null,
			type: "rectangle",
			name: "Rectangle 1",
			x: 50,
			y: 50,
			width: 200,
			height: 150,
			fills: [{ color: 0xff3b82f6, opacity: 1.0 }],
			strokes: [{ color: 0xff1d4ed8, width: 2 }],
			opacity: 1,
			hidden: false,
			blocked: false,
			rotation: 0,
			sortOrder: 1,
			properties: { r1: 8, r2: 8, r3: 8, r4: 8, frameId: SHAPE_FRAME_ID },
		},
		{
			id: SHAPE_RECT_2_ID,
			projectId: DEMO_PROJECT_ID,
			frameId: null,
			parentId: null,
			type: "rectangle",
			name: "Rectangle 2",
			x: 300,
			y: 100,
			width: 180,
			height: 120,
			fills: [
				{
					color: 0xff22c55e,
					opacity: 1.0,
					gradient: {
						type: "linear",
						stops: [
							{ color: 0xff22c55e, offset: 0.0, opacity: 1.0 },
							{ color: 0xff3b82f6, offset: 1.0, opacity: 1.0 },
						],
						startX: 0.0,
						startY: 0.0,
						endX: 1.0,
						endY: 1.0,
					},
				},
			],
			strokes: [{ color: 0xff16a34a, width: 2 }],
			opacity: 1,
			hidden: false,
			blocked: false,
			rotation: 0,
			sortOrder: 2,
			properties: { frameId: SHAPE_FRAME_ID },
		},
		{
			id: SHAPE_ELLIPSE_1_ID,
			projectId: DEMO_PROJECT_ID,
			frameId: null,
			parentId: null,
			type: "ellipse",
			name: "Ellipse 1",
			x: 520,
			y: 140,
			width: 160,
			height: 120,
			fills: [{ color: 0xffef4444, opacity: 1.0 }],
			strokes: [{ color: 0xffdc2626, width: 2 }],
			opacity: 1,
			hidden: false,
			blocked: false,
			rotation: 0,
			sortOrder: 3,
			properties: { frameId: SHAPE_FRAME_ID },
		},
		{
			id: SHAPE_RECT_3_ID,
			projectId: DEMO_PROJECT_ID,
			frameId: null,
			parentId: null,
			type: "rectangle",
			name: "Rectangle 3",
			x: 100,
			y: 300,
			width: 250,
			height: 180,
			fills: [],
			strokes: [{ color: 0xfffacc15, width: 3, alignment: "inside" }],
			opacity: 1,
			hidden: false,
			blocked: false,
			rotation: 0,
			sortOrder: 4,
			properties: { frameId: SHAPE_FRAME_ID },
		},
		{
			id: SHAPE_ELLIPSE_2_ID,
			projectId: DEMO_PROJECT_ID,
			frameId: null,
			parentId: null,
			type: "ellipse",
			name: "Circle 1",
			x: 480,
			y: 330,
			width: 140,
			height: 140,
			fills: [
				{
					color: 0xffa855f7,
					opacity: 1.0,
					gradient: {
						type: "radial",
						stops: [
							{ color: 0xffa855f7, offset: 0.0, opacity: 1.0 },
							{ color: 0xffec4899, offset: 1.0, opacity: 1.0 },
						],
						startX: 0.5,
						startY: 0.5,
						endX: 1.0,
						endY: 0.5,
					},
				},
			],
			strokes: [{ color: 0xff9333ea, width: 2 }],
			opacity: 1,
			hidden: false,
			blocked: false,
			rotation: 0,
			sortOrder: 5,
			properties: { frameId: SHAPE_FRAME_ID },
		},
	];

	await db.insert(schema.shapes).values(
		shapesData.map((shape) => ({
			id: shape.id,
			projectId: shape.projectId,
			frameId: shape.frameId,
			parentId: shape.parentId,
			type: shape.type,
			name: shape.name,
			x: shape.x,
			y: shape.y,
			width: shape.width,
			height: shape.height,
			rotation: shape.rotation,
			transformA: 1,
			transformB: 0,
			transformC: 0,
			transformD: 1,
			transformE: 0,
			transformF: 0,
			fills: shape.fills,
			strokes: shape.strokes,
			opacity: shape.opacity,
			hidden: shape.hidden,
			blocked: shape.blocked,
			sortOrder: shape.sortOrder,
			properties: shape.properties,
		})),
	);

	const snapshotShapes = shapesData.map((shape) => ({
		id: shape.id,
		name: shape.name,
		type: shape.type,
		x: shape.x,
		y: shape.y,
		width: shape.width,
		height: shape.height,
		frameId: null,
		parentId: shape.parentId,
		sortOrder: shape.sortOrder,
		transformA: 1,
		transformB: 0,
		transformC: 0,
		transformD: 1,
		transformE: 0,
		transformF: 0,
		opacity: shape.opacity,
		hidden: shape.hidden,
		blocked: shape.blocked,
		rotation: shape.rotation,
		fills: shape.fills,
		strokes: shape.strokes,
		properties: shape.properties,
	}));

	await db.insert(schema.snapshots).values({
		id: DEMO_SNAPSHOT_ID,
		projectId: DEMO_PROJECT_ID,
		data: { shapes: snapshotShapes },
	});

	await db.insert(schema.commits).values({
		id: DEMO_COMMIT_ID,
		projectId: DEMO_PROJECT_ID,
		branchId: DEMO_BRANCH_ID,
		parentId: null,
		message: "Initial commit with demo shapes",
		authorId: DEMO_USER_ID,
		snapshotId: DEMO_SNAPSHOT_ID,
	});

	await db
		.update(schema.branches)
		.set({ headCommitId: DEMO_COMMIT_ID })
		.where(eq(schema.branches.id, DEMO_BRANCH_ID));

	console.log("✅ Demo seed completed successfully");
	console.log(`   Project ID: ${DEMO_PROJECT_ID}`);
	console.log(`   Branch ID:  ${DEMO_BRANCH_ID}`);
}

async function seedStressProject(level: StressLevel): Promise<void> {
	const config = createStressConfig(level);
	console.log(`🔥 Seeding stress project (${config.level})...`);

	await cleanupProject(config.projectId);

	const branchIds = Array.from({ length: config.branchCount }, (_, index) =>
		index === 0 ? randomUUID() : randomUUID(),
	);
	const mainBranchId = branchIds[0];

	await db.insert(schema.projects).values({
		id: config.projectId,
		name: config.projectName,
		description: `Stress test dataset (${config.level})`,
		ownerId: DEMO_USER_ID,
		isPublic: false,
		defaultBranchId: mainBranchId,
	});

	await db.insert(schema.branches).values(
		branchIds.map((branchId, index) => ({
			id: branchId,
			projectId: config.projectId,
			name: index === 0 ? "main" : `feature-${index}`,
			description:
				index === 0
					? "Default branch for stress testing"
					: `Stress branch ${index}`,
			isDefault: index === 0,
			isProtected: index === 0,
			createdById: DEMO_USER_ID,
		})),
	);

	const imageSources = await loadImageSources();
	const assets: SeedAsset[] = [];
	const assetRows: Array<typeof schema.projectAssets.$inferInsert> = [];

	for (let index = 0; index < config.assetCount; index++) {
		const source = imageSources[index % imageSources.length];
		const assetId = randomUUID();
		assets.push({
			id: assetId,
			name: source.name,
			width: source.width,
			height: source.height,
		});

		assetRows.push({
			id: assetId,
			projectId: config.projectId,
			name: `${path.parse(source.name).name}-${index + 1}`,
			path: `Stress/${config.level}`,
			mimeType: source.mimeType,
			width: source.width,
			height: source.height,
			data: source.data,
			thumbnail: source.thumbnail,
			fileSize: source.data.byteLength,
		});
	}

	await insertInBatches(assetRows, 50, async (batch) => {
		await db.insert(schema.projectAssets).values(batch);
	});

	const frameRows: Array<typeof schema.frames.$inferInsert> = [];
	const shapeRows: Array<typeof schema.shapes.$inferInsert> = [];
	const frameShapeIds: string[] = [];

	const frameWidth = 3800;
	const frameHeight = 2600;
	const frameSpacingX = 4200;
	const frameSpacingY = 3000;
	const framesPerRow = Math.ceil(Math.sqrt(config.frameCount));

	for (let frameIndex = 0; frameIndex < config.frameCount; frameIndex++) {
		const frameId = randomUUID();
		frameShapeIds.push(frameId);
		const col = frameIndex % framesPerRow;
		const row = Math.floor(frameIndex / framesPerRow);
		const frameX = col * frameSpacingX;
		const frameY = row * frameSpacingY;

		frameRows.push({
			id: frameId,
			projectId: config.projectId,
			name: `Frame ${frameIndex + 1}`,
			x: frameX,
			y: frameY,
			width: frameWidth,
			height: frameHeight,
			backgroundColor: "#1C2128",
			sortOrder: frameIndex,
			clipContent: true,
		});

		shapeRows.push({
			id: frameId,
			projectId: config.projectId,
			frameId: null,
			parentId: null,
			type: "frame",
			name: `Frame ${frameIndex + 1}`,
			x: frameX,
			y: frameY,
			width: frameWidth,
			height: frameHeight,
			rotation: 0,
			transformA: 1,
			transformB: 0,
			transformC: 0,
			transformD: 1,
			transformE: 0,
			transformF: 0,
			fills: [{ color: 0xff1c2128, opacity: 1 }],
			strokes: [{ color: 0xff2d333b, width: 1 }],
			opacity: 1,
			hidden: false,
			blocked: false,
			sortOrder: frameIndex,
			properties: { clipContent: true },
		});

		const columns = 15;
		const rowsInFrame = Math.ceil(config.shapesPerFrame / columns);
		const cellWidth = Math.max(80, Math.floor((frameWidth - 160) / columns));
		const cellHeight = Math.max(
			80,
			Math.floor((frameHeight - 160) / rowsInFrame),
		);

		for (let shapeIndex = 0; shapeIndex < config.shapesPerFrame; shapeIndex++) {
			const globalIndex = frameIndex * config.shapesPerFrame + shapeIndex;
			const localCol = shapeIndex % columns;
			const localRow = Math.floor(shapeIndex / columns);
			const x = frameX + 60 + localCol * cellWidth;
			const y = frameY + 60 + localRow * cellHeight;

			const width = 48 + (globalIndex % 5) * 14;
			const height = 48 + (globalIndex % 7) * 10;
			const shapeTypeIndex = globalIndex % 4;

			if (shapeTypeIndex === 0) {
				shapeRows.push({
					id: randomUUID(),
					projectId: config.projectId,
					frameId,
					parentId: null,
					type: "rectangle",
					name: `Rect ${globalIndex + 1}`,
					x,
					y,
					width,
					height,
					rotation: 0,
					transformA: 1,
					transformB: 0,
					transformC: 0,
					transformD: 1,
					transformE: 0,
					transformF: 0,
					fills: [{ color: 0xff4c9aff, opacity: 1 }],
					strokes: [{ color: 0xff2f81f7, width: 1 }],
					opacity: 1,
					hidden: false,
					blocked: false,
					sortOrder: shapeIndex + 1,
					properties: {
						r1: globalIndex % 8,
						r2: globalIndex % 8,
						r3: globalIndex % 8,
						r4: globalIndex % 8,
						frameId,
					},
				});
				continue;
			}

			if (shapeTypeIndex === 1) {
				shapeRows.push({
					id: randomUUID(),
					projectId: config.projectId,
					frameId,
					parentId: null,
					type: "ellipse",
					name: `Ellipse ${globalIndex + 1}`,
					x,
					y,
					width,
					height,
					rotation: 0,
					transformA: 1,
					transformB: 0,
					transformC: 0,
					transformD: 1,
					transformE: 0,
					transformF: 0,
					fills: [{ color: 0xff7ee787, opacity: 1 }],
					strokes: [{ color: 0xff3fb950, width: 1 }],
					opacity: 1,
					hidden: false,
					blocked: false,
					sortOrder: shapeIndex + 1,
					properties: { frameId },
				});
				continue;
			}

			if (shapeTypeIndex === 2) {
				shapeRows.push({
					id: randomUUID(),
					projectId: config.projectId,
					frameId,
					parentId: null,
					type: "text",
					name: `Text ${globalIndex + 1}`,
					x,
					y,
					width: width + 40,
					height,
					rotation: 0,
					transformA: 1,
					transformB: 0,
					transformC: 0,
					transformD: 1,
					transformE: 0,
					transformF: 0,
					fills: [{ color: 0xffe6edf3, opacity: 1 }],
					strokes: [],
					opacity: 1,
					hidden: false,
					blocked: false,
					sortOrder: shapeIndex + 1,
					properties: {
						frameId,
						text: `stress-${config.level}-${globalIndex + 1}`,
						fontSize: 14,
						fontFamily: "Inter",
						fontWeight: 500,
						textAlign: "left",
					},
				});
				continue;
			}

			const asset = assets[globalIndex % assets.length];
			shapeRows.push({
				id: randomUUID(),
				projectId: config.projectId,
				frameId,
				parentId: null,
				type: "image",
				name: `Image ${globalIndex + 1}`,
				x,
				y,
				width: width + 24,
				height: height + 24,
				rotation: 0,
				transformA: 1,
				transformB: 0,
				transformC: 0,
				transformD: 1,
				transformE: 0,
				transformF: 0,
				fills: [],
				strokes: [{ color: 0xff8b949e, width: 1 }],
				opacity: 1,
				hidden: false,
				blocked: false,
				sortOrder: shapeIndex + 1,
				properties: {
					frameId,
					assetId: asset.id,
					originalWidth: asset.width,
					originalHeight: asset.height,
					scaleMode: "fill",
				},
			});
		}
	}

	await insertInBatches(frameRows, 200, async (batch) => {
		await db.insert(schema.frames).values(batch);
	});

	await insertInBatches(shapeRows, 500, async (batch) => {
		await db.insert(schema.shapes).values(batch);
	});

	const snapshotShapes = shapeRows.map((shape) => ({
		id: shape.id,
		name: shape.name,
		type: shape.type,
		x: shape.x,
		y: shape.y,
		width: shape.width,
		height: shape.height,
		frameId: shape.frameId,
		parentId: shape.parentId,
		sortOrder: shape.sortOrder,
		transformA: shape.transformA,
		transformB: shape.transformB,
		transformC: shape.transformC,
		transformD: shape.transformD,
		transformE: shape.transformE,
		transformF: shape.transformF,
		opacity: shape.opacity,
		hidden: shape.hidden,
		blocked: shape.blocked,
		rotation: shape.rotation,
		fills: shape.fills,
		strokes: shape.strokes,
		properties: shape.properties,
	}));

	for (let branchIndex = 0; branchIndex < branchIds.length; branchIndex++) {
		const branchId = branchIds[branchIndex];
		const snapshotId = randomUUID();
		await db.insert(schema.snapshots).values({
			id: snapshotId,
			projectId: config.projectId,
			data: { shapes: snapshotShapes },
		});

		let parentCommitId: string | null = null;
		let headCommitId: string | null = null;

		for (
			let commitIndex = 0;
			commitIndex < config.commitsPerBranch;
			commitIndex++
		) {
			const commitId = randomUUID();
			headCommitId = commitId;

			await db.insert(schema.commits).values({
				id: commitId,
				projectId: config.projectId,
				branchId,
				parentId: parentCommitId,
				message: `Stress ${config.level} commit ${commitIndex + 1}/${config.commitsPerBranch}`,
				authorId: DEMO_USER_ID,
				snapshotId,
			});

			parentCommitId = commitId;
		}

		await db
			.update(schema.branches)
			.set({ headCommitId })
			.where(eq(schema.branches.id, branchId));
	}

	console.log("✅ Stress seed completed successfully");
	console.log(`   Project:      ${config.projectName}`);
	console.log(`   Project ID:   ${config.projectId}`);
	console.log(`   Frames:       ${config.frameCount}`);
	console.log(`   Shape rows:   ${shapeRows.length}`);
	console.log(`   Assets:       ${assetRows.length}`);
	console.log(`   Branches:     ${branchIds.length}`);
	console.log(`   Commits:      ${branchIds.length * config.commitsPerBranch}`);
	console.log(`   Images source: ${STRESS_IMAGES_DIR}`);
}

async function seed(): Promise<void> {
	console.log("🌱 Starting database seed...");
	try {
		const stressLevel = parseStressLevelArg();
		if (stressLevel) {
			await seedStressProject(stressLevel);
		} else {
			await seedDemoProject();
		}
	} catch (error) {
		console.error("❌ Seed failed:", error);
		process.exit(1);
	}

	process.exit(0);
}

void seed();
