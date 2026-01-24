import type { ConnectRouter } from "@connectrpc/connect";
import { Code, ConnectError } from "@connectrpc/connect";
import { and, asc, eq } from "drizzle-orm";
import { db, schema } from "../db";
import {
	Fill,
	Timestamp as ProtoTimestamp,
	Stroke,
	StrokeAlignment,
	Transform,
} from "../gen/vio/v1/common_pb.js";
import { ShapeService } from "../gen/vio/v1/shape_connect.js";
import {
	BatchMutateResponse,
	CreateShapeResponse,
	GetShapeResponse,
	ListShapesResponse,
	Shape,
	ShapeType,
	UpdateShapeResponse,
} from "../gen/vio/v1/shape_pb.js";

function toProtoTimestamp(date: Date): ProtoTimestamp {
	return new ProtoTimestamp({
		millis: BigInt(date.getTime()),
	});
}

// ============================================================================
// Enum conversion helpers
// ============================================================================

function stringToShapeType(type: string): ShapeType {
	const mapping: Record<string, ShapeType> = {
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
	return mapping[type.toLowerCase()] ?? ShapeType.UNSPECIFIED;
}

function stringToStrokeAlignment(alignment: string): StrokeAlignment {
	const mapping: Record<string, StrokeAlignment> = {
		center: StrokeAlignment.CENTER,
		inside: StrokeAlignment.INSIDE,
		outside: StrokeAlignment.OUTSIDE,
	};
	return mapping[alignment.toLowerCase()] ?? StrokeAlignment.CENTER;
}

interface DbFill {
	color?: number;
	opacity?: number;
}

interface DbStroke {
	color?: number;
	width?: number;
	opacity?: number;
	alignment?: string;
}

function toProtoShape(dbShape: typeof schema.shapes.$inferSelect): Shape {
	return new Shape({
		id: dbShape.id,
		projectId: dbShape.projectId,
		frameId: dbShape.frameId ?? undefined,
		parentId: dbShape.parentId ?? undefined,
		type: stringToShapeType(dbShape.type),
		name: dbShape.name,
		x: dbShape.x,
		y: dbShape.y,
		width: dbShape.width,
		height: dbShape.height,
		rotation: dbShape.rotation,
		transform: new Transform({
			a: dbShape.transformA,
			b: dbShape.transformB,
			c: dbShape.transformC,
			d: dbShape.transformD,
			e: dbShape.transformE,
			f: dbShape.transformF,
		}),
		fills: ((dbShape.fills as DbFill[]) || []).map(
			(f) =>
				new Fill({
					color: f.color ?? 0,
					opacity: f.opacity ?? 1.0,
				}),
		),
		strokes: ((dbShape.strokes as DbStroke[]) || []).map(
			(st) =>
				new Stroke({
					color: st.color ?? 0,
					width: st.width ?? 1.0,
					opacity: st.opacity ?? 1.0,
					alignment: stringToStrokeAlignment(st.alignment ?? "center"),
				}),
		),
		opacity: dbShape.opacity,
		hidden: dbShape.hidden,
		blocked: dbShape.blocked,
		sortOrder: dbShape.sortOrder,
		properties: new TextEncoder().encode(JSON.stringify(dbShape.properties || {})),
		createdAt: toProtoTimestamp(new Date(dbShape.createdAt)),
		updatedAt: toProtoTimestamp(new Date(dbShape.updatedAt)),
	});
}

export function registerShapeService(router: ConnectRouter) {
	router.service(ShapeService, {
		async listShapes(req) {
			const whereClause = req.frameId
				? and(
						eq(schema.shapes.projectId, req.projectId),
						eq(schema.shapes.frameId, req.frameId),
					)
				: eq(schema.shapes.projectId, req.projectId);

			const shapes = await db
				.select()
				.from(schema.shapes)
				.where(whereClause)
				.orderBy(asc(schema.shapes.sortOrder));

			return new ListShapesResponse({
				shapes: shapes.map(toProtoShape),
			});
		},

		async getShape(req) {
			const shape = await db.query.shapes.findFirst({
				where: and(
					eq(schema.shapes.id, req.shapeId),
					eq(schema.shapes.projectId, req.projectId),
				),
				with: {
					children: true,
				},
			});

			if (!shape) {
				throw new ConnectError("Shape not found", Code.NotFound);
			}

			return new GetShapeResponse({
				shape: toProtoShape(shape),
				children: shape.children.map(toProtoShape),
			});
		},

		async createShape(req) {
			const [created] = await db
				.insert(schema.shapes)
				.values({
					projectId: req.projectId,
					frameId: req.frameId || null,
					parentId: req.parentId || null,
					type: req.type.toString(),
					name: req.name,
					x: req.x,
					y: req.y,
					width: req.width,
					height: req.height,
					rotation: req.rotation ?? 0,
					transformA: req.transform?.a ?? 1,
					transformB: req.transform?.b ?? 0,
					transformC: req.transform?.c ?? 0,
					transformD: req.transform?.d ?? 1,
					transformE: req.transform?.e ?? 0,
					transformF: req.transform?.f ?? 0,
					fills: req.fills.map((f) => ({
						color: f.color,
						opacity: f.opacity,
					})),
					strokes: req.strokes.map((s) => ({
						color: s.color,
						width: s.width,
						opacity: s.opacity,
						alignment: s.alignment,
					})),
					opacity: req.opacity ?? 1.0,
					hidden: false,
					blocked: false,
					sortOrder: req.sortOrder ?? 0,
					properties: req.properties
						? JSON.parse(new TextDecoder().decode(req.properties))
						: {},
				})
				.returning();

			return new CreateShapeResponse({
				shape: toProtoShape(created),
			});
		},

		async updateShape(req) {
			const updateData: Record<string, unknown> = {
				updatedAt: new Date(),
			};

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
			if (req.parentId !== undefined)
				updateData.parentId = req.parentId || null;

			if (req.transform) {
				updateData.transformA = req.transform.a;
				updateData.transformB = req.transform.b;
				updateData.transformC = req.transform.c;
				updateData.transformD = req.transform.d;
				updateData.transformE = req.transform.e;
				updateData.transformF = req.transform.f;
			}

			if (req.fills.length > 0) {
				updateData.fills = req.fills.map((f) => ({
					color: f.color,
					opacity: f.opacity,
				}));
			}

			if (req.strokes.length > 0) {
				updateData.strokes = req.strokes.map((s) => ({
					color: s.color,
					width: s.width,
					opacity: s.opacity,
					alignment: s.alignment,
				}));
			}

			if (req.properties) {
				updateData.properties = JSON.parse(
					new TextDecoder().decode(req.properties),
				);
			}

			const [updated] = await db
				.update(schema.shapes)
				.set(updateData)
				.where(
					and(
						eq(schema.shapes.id, req.shapeId),
						eq(schema.shapes.projectId, req.projectId),
					),
				)
				.returning();

			if (!updated) {
				throw new ConnectError("Shape not found", Code.NotFound);
			}

			return new UpdateShapeResponse({
				shape: toProtoShape(updated),
			});
		},

		async deleteShape(req) {
			const [deleted] = await db
				.delete(schema.shapes)
				.where(
					and(
						eq(schema.shapes.id, req.shapeId),
						eq(schema.shapes.projectId, req.projectId),
					),
				)
				.returning();

			if (!deleted) {
				throw new ConnectError("Shape not found", Code.NotFound);
			}

			return {};
		},

		async batchMutate(req) {
			const createdShapes: Shape[] = [];
			const updatedShapes: Shape[] = [];
			const deletedIds: string[] = [];

			// Process creates
			if (req.create.length > 0) {
				for (const createReq of req.create) {
					const [created] = await db
						.insert(schema.shapes)
						.values({
							projectId: req.projectId,
							frameId: createReq.frameId || null,
							parentId: createReq.parentId || null,
							type: createReq.type.toString(),
							name: createReq.name,
							x: createReq.x,
							y: createReq.y,
							width: createReq.width,
							height: createReq.height,
							rotation: createReq.rotation ?? 0,
							transformA: createReq.transform?.a ?? 1,
							transformB: createReq.transform?.b ?? 0,
							transformC: createReq.transform?.c ?? 0,
							transformD: createReq.transform?.d ?? 1,
							transformE: createReq.transform?.e ?? 0,
							transformF: createReq.transform?.f ?? 0,
							fills: createReq.fills.map((f) => ({
								color: f.color,
								opacity: f.opacity,
							})),
							strokes: createReq.strokes.map((s) => ({
								color: s.color,
								width: s.width,
								opacity: s.opacity,
								alignment: s.alignment,
							})),
							opacity: createReq.opacity ?? 1.0,
							hidden: false,
							blocked: false,
							sortOrder: createReq.sortOrder ?? 0,
							properties: createReq.properties
								? JSON.parse(new TextDecoder().decode(createReq.properties))
								: {},
						})
						.returning();

					createdShapes.push(toProtoShape(created));
				}
			}

			// Process updates
			for (const updateReq of req.update) {
				const updateData: Record<string, unknown> = { updatedAt: new Date() };

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
					updateData.fills = updateReq.fills.map((f) => ({
						color: f.color,
						opacity: f.opacity,
					}));
				}

				if (updateReq.strokes.length > 0) {
					updateData.strokes = updateReq.strokes.map((s) => ({
						color: s.color,
						width: s.width,
						opacity: s.opacity,
						alignment: s.alignment,
					}));
				}

				if (updateReq.properties) {
					updateData.properties = JSON.parse(
						new TextDecoder().decode(updateReq.properties),
					);
				}

				const [updated] = await db
					.update(schema.shapes)
					.set(updateData)
					.where(
						and(
							eq(schema.shapes.id, updateReq.shapeId),
							eq(schema.shapes.projectId, req.projectId),
						),
					)
					.returning();

				if (updated) {
					updatedShapes.push(toProtoShape(updated));
				}
			}

			// Process deletes
			for (const shapeId of req.deleteIds) {
				const [deleted] = await db
					.delete(schema.shapes)
					.where(
						and(
							eq(schema.shapes.id, shapeId),
							eq(schema.shapes.projectId, req.projectId),
						),
					)
					.returning();

				if (deleted) {
					deletedIds.push(shapeId);
				}
			}

			return new BatchMutateResponse({
				created: createdShapes,
				updated: updatedShapes,
				deletedIds,
			});
		},
	});
}
