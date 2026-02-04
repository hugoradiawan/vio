/**
 * Shape service implementation for Vio design tool.
 * Handles CRUD operations for shapes on the canvas.
 */

import { create } from "@bufbuild/protobuf";
import type { ServiceImpl } from "@connectrpc/connect";
import { and, eq } from "drizzle-orm";
import { db } from "../db/index.js";
import { shapes } from "../db/schema/index.js";
import {
    EmptySchema,
    FillSchema,
    StrokeAlignment,
    StrokeCap,
    StrokeJoin,
    StrokeSchema,
    TimestampSchema,
    TransformSchema,
    type Empty,
    type Fill,
    type Stroke,
    type Timestamp,
    type Transform,
} from "../gen/vio/v1/common_pb.js";
import {
    BatchMutateResponseSchema,
    CreateShapeResponseSchema,
    GetShapeResponseSchema,
    ListShapesResponseSchema,
    ShapeSchema,
    ShapeService,
    ShapeType,
    UpdateShapeResponseSchema,
    type BatchMutateRequest,
    type BatchMutateResponse,
    type CreateShapeRequest,
    type CreateShapeResponse,
    type GetShapeResponse,
    type ListShapesResponse,
    type Shape as ProtoShape,
    type UpdateShapeResponse,
} from "../gen/vio/v1/shape_pb.js";
import { notFound } from "./errors.js";

/**
 * Convert a JavaScript Date to a protobuf Timestamp
 */
function toProtoTimestamp(date: Date): Timestamp {
	return create(TimestampSchema, { millis: BigInt(date.getTime()) });
}

/**
 * Convert a string shape type to the protobuf ShapeType enum
 */
function stringToShapeType(type: string): ShapeType {
	const typeMap: Record<string, ShapeType> = {
		rectangle: ShapeType.RECTANGLE,
		ellipse: ShapeType.ELLIPSE,
		path: ShapeType.PATH,
		text: ShapeType.TEXT,
		frame: ShapeType.FRAME,
		group: ShapeType.GROUP,
		image: ShapeType.IMAGE,
		svg: ShapeType.SVG,
		bool: ShapeType.BOOL,
	};
	return typeMap[type.toLowerCase()] ?? ShapeType.UNSPECIFIED;
}

/**
 * Convert a protobuf ShapeType enum to a string
 */
function shapeTypeToString(type: ShapeType): string {
	const typeMap: Record<number, string> = {
		[ShapeType.UNSPECIFIED]: "rectangle",
		[ShapeType.RECTANGLE]: "rectangle",
		[ShapeType.ELLIPSE]: "ellipse",
		[ShapeType.PATH]: "path",
		[ShapeType.TEXT]: "text",
		[ShapeType.FRAME]: "frame",
		[ShapeType.GROUP]: "group",
		[ShapeType.IMAGE]: "image",
		[ShapeType.SVG]: "svg",
		[ShapeType.BOOL]: "bool",
	};
	return typeMap[type] ?? "rectangle";
}

/**
 * Convert a database shape row to a protobuf Shape message
 */
function toProtoShape(row: typeof shapes.$inferSelect): ProtoShape {
	// Parse fills and strokes from JSON
	const fillsJson = (row.fills as unknown[]) || [];
	const strokesJson = (row.strokes as unknown[]) || [];

	const protoFills: Fill[] = fillsJson.map((f: unknown) => {
		const fill = f as Record<string, unknown>;
		return create(FillSchema, {
			color: (fill.color as number) ?? 0,
			opacity: (fill.opacity as number) ?? 1.0,
		});
	});

	const protoStrokes: Stroke[] = strokesJson.map((s: unknown) => {
		const stroke = s as Record<string, unknown>;
		return create(StrokeSchema, {
			color: (stroke.color as number) ?? 0,
			width: (stroke.width as number) ?? 1.0,
			opacity: (stroke.opacity as number) ?? 1.0,
			alignment: StrokeAlignment.CENTER,
			cap: StrokeCap.ROUND,
			join: StrokeJoin.ROUND,
		});
	});

	const transform: Transform = create(TransformSchema, {
		a: row.transformA,
		b: row.transformB,
		c: row.transformC,
		d: row.transformD,
		e: row.transformE,
		f: row.transformF,
	});

	// Convert properties JSONB to bytes
	const propsJson = row.properties as Record<string, unknown>;
	const propsBytes =
		propsJson && Object.keys(propsJson).length > 0
			? new TextEncoder().encode(JSON.stringify(propsJson))
			: new Uint8Array(0);

	return create(ShapeSchema, {
		id: row.id,
		projectId: row.projectId,
		frameId: row.frameId ?? undefined,
		parentId: row.parentId ?? undefined,
		type: stringToShapeType(row.type),
		name: row.name,
		transform,
		x: row.x,
		y: row.y,
		width: row.width,
		height: row.height,
		rotation: row.rotation,
		fills: protoFills,
		strokes: protoStrokes,
		opacity: row.opacity,
		hidden: row.hidden,
		blocked: row.blocked,
		sortOrder: row.sortOrder,
		properties: propsBytes,
		createdAt: toProtoTimestamp(row.createdAt),
		updatedAt: toProtoTimestamp(row.updatedAt),
	});
}

/**
 * Default transform values
 */
const defaultTransform: Transform = create(TransformSchema, {
	a: 1,
	b: 0,
	c: 0,
	d: 1,
	e: 0,
	f: 0,
});

/**
 * Shape service implementation
 */
export const shapeServiceImpl: ServiceImpl<typeof ShapeService> = {
	/**
	 * List all shapes in a project, optionally filtered by frame
	 */
	async listShapes(req): Promise<ListShapesResponse> {
		const whereConditions = [eq(shapes.projectId, req.projectId)];

		if (req.frameId) {
			whereConditions.push(eq(shapes.frameId, req.frameId));
		}

		const rows = await db
			.select()
			.from(shapes)
			.where(and(...whereConditions))
			.orderBy(shapes.sortOrder);

		return create(ListShapesResponseSchema, {
			shapes: rows.map(toProtoShape),
		});
	},

	/**
	 * Get a single shape by ID
	 */
	async getShape(req): Promise<GetShapeResponse> {
		const [row] = await db
			.select()
			.from(shapes)
			.where(eq(shapes.id, req.shapeId))
			.limit(1);

		if (!row) {
			throw notFound(`Shape not found: ${req.shapeId}`);
		}

		// Get children if it's a group or frame
		const childRows = await db
			.select()
			.from(shapes)
			.where(eq(shapes.parentId, req.shapeId))
			.orderBy(shapes.sortOrder);

		return create(GetShapeResponseSchema, {
			shape: toProtoShape(row),
			children: childRows.map(toProtoShape),
		});
	},

	/**
	 * Create a new shape
	 */
	async createShape(req: CreateShapeRequest): Promise<CreateShapeResponse> {
		const transform = req.transform ?? defaultTransform;

		const fillsJson = req.fills.map((f: Fill) => ({
			color: f.color,
			opacity: f.opacity,
		}));

		const strokesJson = req.strokes.map((s: Stroke) => ({
			color: s.color,
			width: s.width,
			opacity: s.opacity,
		}));

		const propertiesJson =
			req.properties && req.properties.length > 0
				? JSON.parse(new TextDecoder().decode(req.properties))
				: {};

		const [created] = await db
			.insert(shapes)
			.values({
				projectId: req.projectId,
				frameId: req.frameId ?? null,
				parentId: req.parentId ?? null,
				type: shapeTypeToString(req.type),
				name: req.name,
				x: req.x,
				y: req.y,
				width: req.width,
				height: req.height,
				rotation: req.rotation ?? 0,
				transformA: transform.a,
				transformB: transform.b,
				transformC: transform.c,
				transformD: transform.d,
				transformE: transform.e,
				transformF: transform.f,
				fills: fillsJson,
				strokes: strokesJson,
				opacity: req.opacity ?? 1.0,
				hidden: false,
				blocked: false,
				properties: propertiesJson,
				sortOrder: req.sortOrder ?? 0,
			})
			.returning();

		return create(CreateShapeResponseSchema, {
			shape: toProtoShape(created),
		});
	},

	/**
	 * Update an existing shape
	 */
	async updateShape(req): Promise<UpdateShapeResponse> {
		// Build update object dynamically
		const updateData: Record<string, unknown> = {
			updatedAt: new Date(),
		};

		// Only update fields that are provided
		if (req.name !== undefined) updateData.name = req.name;
		if (req.x !== undefined) updateData.x = req.x;
		if (req.y !== undefined) updateData.y = req.y;
		if (req.width !== undefined) updateData.width = req.width;
		if (req.height !== undefined) updateData.height = req.height;
		if (req.rotation !== undefined) updateData.rotation = req.rotation;
		if (req.opacity !== undefined) updateData.opacity = req.opacity;
		if (req.hidden !== undefined) updateData.hidden = req.hidden;
		if (req.blocked !== undefined) updateData.blocked = req.blocked;
		if (req.sortOrder !== undefined) updateData.sortOrder = req.sortOrder;
		if (req.frameId !== undefined) updateData.frameId = req.frameId || null;
		if (req.parentId !== undefined) updateData.parentId = req.parentId || null;

		if (req.transform) {
			updateData.transformA = req.transform.a;
			updateData.transformB = req.transform.b;
			updateData.transformC = req.transform.c;
			updateData.transformD = req.transform.d;
			updateData.transformE = req.transform.e;
			updateData.transformF = req.transform.f;
		}

		if (req.fills.length > 0) {
			updateData.fills = req.fills.map((f: Fill) => ({
				color: f.color,
				opacity: f.opacity,
			}));
		}

		if (req.strokes.length > 0) {
			updateData.strokes = req.strokes.map((s: Stroke) => ({
				color: s.color,
				width: s.width,
				opacity: s.opacity,
			}));
		}

		if (req.properties && req.properties.length > 0) {
			updateData.properties = JSON.parse(
				new TextDecoder().decode(req.properties),
			);
		}

		const [updated] = await db
			.update(shapes)
			.set(updateData)
			.where(
				and(eq(shapes.id, req.shapeId), eq(shapes.projectId, req.projectId)),
			)
			.returning();

		if (!updated) {
			throw notFound(`Shape not found: ${req.shapeId}`);
		}

		return create(UpdateShapeResponseSchema, {
			shape: toProtoShape(updated),
		});
	},

	/**
	 * Delete a shape
	 */
	async deleteShape(req): Promise<Empty> {
		const result = await db
			.delete(shapes)
			.where(
				and(eq(shapes.id, req.shapeId), eq(shapes.projectId, req.projectId)),
			);

		// Check if any row was deleted (result varies by driver)
		if (!result) {
			throw notFound(`Shape not found: ${req.shapeId}`);
		}

		return create(EmptySchema, {});
	},

	/**
	 * Batch create, update, and delete shapes
	 */
	async batchMutate(req: BatchMutateRequest): Promise<BatchMutateResponse> {
		const createdShapes: ProtoShape[] = [];
		const updatedShapes: ProtoShape[] = [];
		const deletedIds: string[] = [];

		// Process creates
		for (const createReq of req.create) {
			try {
				const transform = createReq.transform ?? defaultTransform;

				const fillsJson = createReq.fills.map((f: Fill) => ({
					color: f.color,
					opacity: f.opacity,
				}));

				const strokesJson = createReq.strokes.map((s: Stroke) => ({
					color: s.color,
					width: s.width,
					opacity: s.opacity,
				}));

				const propertiesJson =
					createReq.properties && createReq.properties.length > 0
						? JSON.parse(new TextDecoder().decode(createReq.properties))
						: {};

				const [created] = await db
					.insert(shapes)
					.values({
						projectId: req.projectId,
						frameId: createReq.frameId ?? null,
						parentId: createReq.parentId ?? null,
						type: shapeTypeToString(createReq.type),
						name: createReq.name,
						x: createReq.x,
						y: createReq.y,
						width: createReq.width,
						height: createReq.height,
						rotation: createReq.rotation ?? 0,
						transformA: transform.a,
						transformB: transform.b,
						transformC: transform.c,
						transformD: transform.d,
						transformE: transform.e,
						transformF: transform.f,
						fills: fillsJson,
						strokes: strokesJson,
						opacity: createReq.opacity ?? 1.0,
						hidden: false,
						blocked: false,
						properties: propertiesJson,
						sortOrder: createReq.sortOrder ?? 0,
					})
					.returning();

				createdShapes.push(toProtoShape(created));
			} catch (error) {
				console.error("Failed to create shape in batch:", error);
			}
		}

		// Process updates
		for (const updateReq of req.update) {
			try {
				const updateData: Record<string, unknown> = {
					updatedAt: new Date(),
				};

				if (updateReq.name !== undefined) updateData.name = updateReq.name;
				if (updateReq.x !== undefined) updateData.x = updateReq.x;
				if (updateReq.y !== undefined) updateData.y = updateReq.y;
				if (updateReq.width !== undefined) updateData.width = updateReq.width;
				if (updateReq.height !== undefined)
					updateData.height = updateReq.height;
				if (updateReq.rotation !== undefined)
					updateData.rotation = updateReq.rotation;
				if (updateReq.opacity !== undefined)
					updateData.opacity = updateReq.opacity;
				if (updateReq.hidden !== undefined)
					updateData.hidden = updateReq.hidden;
				if (updateReq.blocked !== undefined)
					updateData.blocked = updateReq.blocked;
				if (updateReq.sortOrder !== undefined)
					updateData.sortOrder = updateReq.sortOrder;
				if (updateReq.frameId !== undefined)
					updateData.frameId = updateReq.frameId || null;
				if (updateReq.parentId !== undefined)
					updateData.parentId = updateReq.parentId || null;

				if (updateReq.transform) {
					updateData.transformA = updateReq.transform.a;
					updateData.transformB = updateReq.transform.b;
					updateData.transformC = updateReq.transform.c;
					updateData.transformD = updateReq.transform.d;
					updateData.transformE = updateReq.transform.e;
					updateData.transformF = updateReq.transform.f;
				}

				if (updateReq.fills.length > 0) {
					updateData.fills = updateReq.fills.map((f: Fill) => ({
						color: f.color,
						opacity: f.opacity,
					}));
				}

				if (updateReq.strokes.length > 0) {
					updateData.strokes = updateReq.strokes.map((s: Stroke) => ({
						color: s.color,
						width: s.width,
						opacity: s.opacity,
					}));
				}

				if (updateReq.properties && updateReq.properties.length > 0) {
					updateData.properties = JSON.parse(
						new TextDecoder().decode(updateReq.properties),
					);
				}

				const [updated] = await db
					.update(shapes)
					.set(updateData)
					.where(
						and(
							eq(shapes.id, updateReq.shapeId),
							eq(shapes.projectId, req.projectId),
						),
					)
					.returning();

				if (updated) {
					updatedShapes.push(toProtoShape(updated));
				}
			} catch (error) {
				console.error("Failed to update shape in batch:", error);
			}
		}

		// Process deletes
		for (const shapeId of req.deleteIds) {
			try {
				await db
					.delete(shapes)
					.where(
						and(eq(shapes.id, shapeId), eq(shapes.projectId, req.projectId)),
					);
				deletedIds.push(shapeId);
			} catch (error) {
				console.error("Failed to delete shape in batch:", error);
			}
		}

		return create(BatchMutateResponseSchema, {
			created: createdShapes,
			updated: updatedShapes,
			deletedIds,
		});
	},
};
