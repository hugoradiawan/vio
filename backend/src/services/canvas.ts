/**
 * Canvas service implementation for real-time collaboration.
 * Handles canvas state, sync, and bidirectional streaming for presence.
 */

import { create } from "@bufbuild/protobuf";
import type { ServiceImpl } from "@connectrpc/connect";
import { and, asc, eq } from "drizzle-orm";
import { db, schema } from "../db";
import {
	type CanvasService,
	CanvasStateSchema,
	type CanvasUpdate,
	CanvasUpdateSchema,
	ClearWorkingCopyResponseSchema,
	type CollaborateResponse,
	CollaborateResponseSchema,
	CursorMovedSchema,
	type CursorPosition,
	CursorPositionSchema,
	type GetCanvasStateResponse,
	GetCanvasStateResponseSchema,
	OperationType,
	RestoreFromSnapshotResponseSchema,
	SelectionChangedSchema,
	SessionJoinedSchema,
	ShapeCreatedSchema,
	ShapeDeletedSchema,
	ShapeUpdatedSchema,
	SyncAckSchema,
	type SyncChangesResponse,
	SyncChangesResponseSchema,
	type SyncOperation,
	UserJoinedSchema,
	UserLeftSchema,
	type UserPresence,
	UserPresenceSchema,
} from "../gen/vio/v1/canvas_pb.js";
import {
	type Fill,
	FillSchema,
	type Gradient,
	Gradient_Type,
	GradientSchema,
	GradientStopSchema,
	type Stroke,
	StrokeAlignment,
	StrokeCap,
	StrokeJoin,
	StrokeSchema,
	type Timestamp,
	TimestampSchema,
	TransformSchema,
} from "../gen/vio/v1/common_pb.js";
import { type Shape, ShapeSchema, ShapeType } from "../gen/vio/v1/shape_pb.js";
import { startPerfSpan } from "../utils/perf-diagnostics.js";
import { invalidArgument, notFound } from "./errors.js";

// ============================================================================
// Collaboration State (in-memory for now)
// ============================================================================

interface Collaborator {
	userId: string;
	userName: string;
	projectId: string;
	branchId: string;
	cursor?: { x: number; y: number };
	color?: string;
	selection: string[];
	lastSeen: number;
}

const collaborators = new Map<string, Collaborator>();
const updateSubscribers = new Map<
	string,
	Set<(update: CanvasUpdate) => void>
>();

function getChannelKey(projectId: string, branchId: string): string {
	return `${projectId}:${branchId}`;
}

function broadcastUpdate(
	projectId: string,
	branchId: string,
	update: CanvasUpdate,
) {
	const key = getChannelKey(projectId, branchId);
	const subscribers = updateSubscribers.get(key);
	if (subscribers) {
		for (const callback of subscribers) {
			callback(update);
		}
	}
}

// Cleanup stale collaborators every 30 seconds
setInterval(() => {
	const now = Date.now();
	for (const [id, collab] of collaborators.entries()) {
		if (now - collab.lastSeen > 60_000) {
			collaborators.delete(id);

			// Broadcast user left
			const update = create(CanvasUpdateSchema, {
				update: {
					case: "userLeft",
					value: create(UserLeftSchema, { userId: id }),
				},
				version: BigInt(now),
				timestamp: new Date(now).toISOString(),
			});
			broadcastUpdate(collab.projectId, collab.branchId, update);
		}
	}
}, 30_000);

// ============================================================================
// Helper Functions - Enum conversions
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

function shapeTypeToString(type: ShapeType): string {
	switch (type) {
		case ShapeType.RECTANGLE:
			return "rectangle";
		case ShapeType.ELLIPSE:
			return "ellipse";
		case ShapeType.PATH:
			return "path";
		case ShapeType.TEXT:
			return "text";
		case ShapeType.FRAME:
			return "frame";
		case ShapeType.GROUP:
			return "group";
		case ShapeType.IMAGE:
			return "image";
		case ShapeType.SVG:
			return "svg";
		case ShapeType.BOOL:
			return "bool";
		default:
			return "unspecified";
	}
}

function stringToStrokeAlignment(alignment: string): StrokeAlignment {
	const mapping: Record<string, StrokeAlignment> = {
		center: StrokeAlignment.CENTER,
		inside: StrokeAlignment.INSIDE,
		outside: StrokeAlignment.OUTSIDE,
	};
	return mapping[alignment.toLowerCase()] ?? StrokeAlignment.CENTER;
}

function strokeAlignmentToString(alignment: StrokeAlignment): string {
	switch (alignment) {
		case StrokeAlignment.CENTER:
			return "center";
		case StrokeAlignment.INSIDE:
			return "inside";
		case StrokeAlignment.OUTSIDE:
			return "outside";
		default:
			return "center";
	}
}

function toProtoTimestamp(date: Date): Timestamp {
	return create(TimestampSchema, { millis: BigInt(date.getTime()) });
}

interface DbGradientStop {
	color?: number;
	offset?: number;
	opacity?: number;
}

interface DbGradient {
	type?: string;
	stops?: DbGradientStop[];
	startX?: number;
	startY?: number;
	endX?: number;
	endY?: number;
}

interface DbFill {
	color?: number;
	opacity?: number;
	hidden?: boolean;
	gradient?: DbGradient;
}

interface DbStroke {
	color?: number;
	width?: number;
	opacity?: number;
	alignment?: string;
}

/** Convert a proto Fill to a plain JSON object for DB storage. */
function fillToDb(f: Fill): DbFill {
	const result: DbFill = {
		color: f.color,
		opacity: f.opacity,
	};
	if (f.gradient) {
		result.gradient = {
			type: gradientTypeToString(f.gradient.type),
			stops: f.gradient.stops.map((s) => ({
				color: s.color,
				offset: s.offset,
				opacity: s.opacity,
			})),
			startX: f.gradient.startX,
			startY: f.gradient.startY,
			endX: f.gradient.endX,
			endY: f.gradient.endY,
		};
	}
	return result;
}

/** Convert a DB fill JSON object to a proto Fill. */
function dbToFill(f: DbFill): Fill {
	return create(FillSchema, {
		color: f.color ?? 0,
		opacity: f.opacity ?? 1.0,
		gradient: f.gradient ? dbToGradient(f.gradient) : undefined,
	});
}

function dbToGradient(g: DbGradient): Gradient {
	return create(GradientSchema, {
		type: stringToGradientType(g.type ?? "linear"),
		stops: (g.stops ?? []).map((s) =>
			create(GradientStopSchema, {
				color: s.color ?? 0,
				offset: s.offset ?? 0,
				opacity: s.opacity ?? 1.0,
			}),
		),
		startX: g.startX ?? 0,
		startY: g.startY ?? 0,
		endX: g.endX ?? 1,
		endY: g.endY ?? 1,
	});
}

function gradientTypeToString(type: Gradient_Type): string {
	switch (type) {
		case Gradient_Type.LINEAR:
			return "linear";
		case Gradient_Type.RADIAL:
			return "radial";
		default:
			return "linear";
	}
}

function stringToGradientType(type: string): Gradient_Type {
	switch (type) {
		case "linear":
			return Gradient_Type.LINEAR;
		case "radial":
			return Gradient_Type.RADIAL;
		default:
			return Gradient_Type.LINEAR;
	}
}

function toProtoShape(dbShape: typeof schema.shapes.$inferSelect): Shape {
	const fills: Fill[] = ((dbShape.fills as DbFill[]) || []).map(dbToFill);

	const strokes: Stroke[] = ((dbShape.strokes as DbStroke[]) || []).map((st) =>
		create(StrokeSchema, {
			color: st.color ?? 0,
			width: st.width ?? 1.0,
			opacity: st.opacity ?? 1.0,
			alignment: stringToStrokeAlignment(st.alignment ?? "center"),
			cap: StrokeCap.ROUND,
			join: StrokeJoin.ROUND,
		}),
	);

	return create(ShapeSchema, {
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
		transform: create(TransformSchema, {
			a: dbShape.transformA,
			b: dbShape.transformB,
			c: dbShape.transformC,
			d: dbShape.transformD,
			e: dbShape.transformE,
			f: dbShape.transformF,
		}),
		fills,
		strokes,
		opacity: dbShape.opacity,
		hidden: dbShape.hidden,
		blocked: dbShape.blocked,
		sortOrder: dbShape.sortOrder,
		properties: new TextEncoder().encode(
			JSON.stringify(dbShape.properties || {}),
		),
		createdAt: toProtoTimestamp(new Date(dbShape.createdAt)),
		updatedAt: toProtoTimestamp(new Date(dbShape.updatedAt)),
	});
}

async function processOperation(
	op: SyncOperation,
	projectId: string,
): Promise<Shape | null> {
	try {
		const opType = op.type;

		if (opType === OperationType.CREATE) {
			if (op.shape) {
				const [created] = await db
					.insert(schema.shapes)
					.values({
						id: op.shapeId,
						projectId,
						frameId: op.shape.frameId || null,
						parentId: op.shape.parentId || null,
						type: shapeTypeToString(op.shape.type),
						name: op.shape.name,
						x: op.shape.x,
						y: op.shape.y,
						width: op.shape.width,
						height: op.shape.height,
						rotation: op.shape.rotation || 0,
						transformA: op.shape.transform?.a ?? 1,
						transformB: op.shape.transform?.b ?? 0,
						transformC: op.shape.transform?.c ?? 0,
						transformD: op.shape.transform?.d ?? 1,
						transformE: op.shape.transform?.e ?? 0,
						transformF: op.shape.transform?.f ?? 0,
						fills: op.shape.fills.map(fillToDb),
						strokes: op.shape.strokes.map((s) => ({
							color: s.color,
							width: s.width,
							opacity: s.opacity,
							alignment: strokeAlignmentToString(s.alignment),
						})),
						opacity: op.shape.opacity ?? 1,
						hidden: op.shape.hidden ?? false,
						blocked: op.shape.blocked ?? false,
						properties:
							op.shape.properties.length > 0
								? JSON.parse(new TextDecoder().decode(op.shape.properties))
								: {},
						sortOrder: op.shape.sortOrder ?? 0,
					})
					.returning();
				return toProtoShape(created);
			}
		} else if (opType === OperationType.UPDATE) {
			if (op.shape) {
				const updateData: Record<string, unknown> = { updatedAt: new Date() };
				if (op.shape.frameId !== undefined)
					updateData.frameId = op.shape.frameId || null;
				if (op.shape.parentId !== undefined)
					updateData.parentId = op.shape.parentId || null;
				if (op.shape.type !== ShapeType.UNSPECIFIED)
					updateData.type = shapeTypeToString(op.shape.type);
				if (op.shape.name) updateData.name = op.shape.name;
				if (op.shape.x !== undefined) updateData.x = op.shape.x;
				if (op.shape.y !== undefined) updateData.y = op.shape.y;
				if (op.shape.width !== undefined) updateData.width = op.shape.width;
				if (op.shape.height !== undefined) updateData.height = op.shape.height;
				if (op.shape.rotation !== undefined)
					updateData.rotation = op.shape.rotation;
				if (op.shape.opacity !== undefined)
					updateData.opacity = op.shape.opacity;
				if (op.shape.hidden !== undefined) updateData.hidden = op.shape.hidden;
				if (op.shape.blocked !== undefined)
					updateData.blocked = op.shape.blocked;
				if (op.shape.sortOrder !== undefined)
					updateData.sortOrder = op.shape.sortOrder;

				if (op.shape.transform) {
					updateData.transformA = op.shape.transform.a;
					updateData.transformB = op.shape.transform.b;
					updateData.transformC = op.shape.transform.c;
					updateData.transformD = op.shape.transform.d;
					updateData.transformE = op.shape.transform.e;
					updateData.transformF = op.shape.transform.f;
				}

				if (op.shape.fills.length > 0) {
					updateData.fills = op.shape.fills.map(fillToDb);
				}

				if (op.shape.strokes.length > 0) {
					updateData.strokes = op.shape.strokes.map((s) => ({
						color: s.color,
						width: s.width,
						opacity: s.opacity,
						alignment: strokeAlignmentToString(s.alignment),
					}));
				}

				if (op.shape.properties.length > 0) {
					updateData.properties = JSON.parse(
						new TextDecoder().decode(op.shape.properties),
					);
				}

				const [updated] = await db
					.update(schema.shapes)
					.set(updateData)
					.where(
						and(
							eq(schema.shapes.id, op.shapeId),
							eq(schema.shapes.projectId, projectId),
						),
					)
					.returning();
				return updated ? toProtoShape(updated) : null;
			}
		} else if (opType === OperationType.DELETE) {
			await db
				.delete(schema.shapes)
				.where(
					and(
						eq(schema.shapes.id, op.shapeId),
						eq(schema.shapes.projectId, projectId),
					),
				);
			return null;
		}

		return null;
	} catch (error) {
		console.error("Failed to process operation:", error);
		return null;
	}
}

// ============================================================================
// Service Implementation
// ============================================================================

export const canvasServiceImpl: ServiceImpl<typeof CanvasService> = {
	// Get current canvas state
	// Reads from the shapes table (working copy) which includes uncommitted
	// changes synced via auto-sync. Falls back to HEAD commit snapshot if the
	// shapes table has no entries for this project.
	async getCanvasState(req): Promise<GetCanvasStateResponse> {
		const perfSpan = startPerfSpan("canvas.getCanvasState", {
			projectId: req.projectId,
			branchId: req.branchId,
		});
		let source: "workingCopy" | "snapshot" | "empty" = "empty";
		let shapeCount = 0;
		let perfError: unknown;

		try {
			if (!req.projectId || !req.branchId) {
				throw invalidArgument("Project ID and Branch ID are required");
			}

			// Verify project exists
			const project = await db.query.projects.findFirst({
				where: eq(schema.projects.id, req.projectId),
			});

			if (!project) {
				throw notFound("Project not found");
			}

			// Get branch for version info
			const branch = await db.query.branches.findFirst({
				where: and(
					eq(schema.branches.id, req.branchId),
					eq(schema.branches.projectId, req.projectId),
				),
			});

			if (!branch) {
				throw notFound("Branch not found");
			}

			const version = branch.updatedAt
				? BigInt(new Date(branch.updatedAt).getTime())
				: BigInt(Date.now());

			// First, try loading from the shapes table (working copy)
			// This preserves uncommitted changes that were synced before the last restart
			const workingCopyShapes = await db
				.select()
				.from(schema.shapes)
				.where(eq(schema.shapes.projectId, req.projectId))
				.orderBy(asc(schema.shapes.sortOrder));

			if (workingCopyShapes.length > 0) {
				source = "workingCopy";
				shapeCount = workingCopyShapes.length;
				const state = create(CanvasStateSchema, {
					shapes: workingCopyShapes.map(toProtoShape),
					version,
					lastModified: branch.updatedAt
						? new Date(branch.updatedAt).toISOString()
						: new Date().toISOString(),
				});

				return create(GetCanvasStateResponseSchema, { state });
			}

			// No shapes in working copy — fall back to HEAD commit snapshot
			if (branch.headCommitId) {
				const commit = await db.query.commits.findFirst({
					where: eq(schema.commits.id, branch.headCommitId),
				});

				if (commit?.snapshotId) {
					const snapshot = await db.query.snapshots.findFirst({
						where: eq(schema.snapshots.id, commit.snapshotId),
					});

					if (snapshot) {
						const snapshotData = snapshot.data as {
							shapes?: Array<Record<string, unknown>>;
						};
						const snapshotShapes = snapshotData.shapes ?? [];
						source = "snapshot";
						shapeCount = snapshotShapes.length;

						// Convert snapshot shapes to proto format
						const protoShapes: Shape[] = snapshotShapes.map((shape) => {
							// Parse fills and strokes from snapshot format
							const fills: Fill[] = ((shape.fills as DbFill[]) || []).map(
								dbToFill,
							);

							const strokes: Stroke[] = (
								(shape.strokes as DbStroke[]) || []
							).map((st) =>
								create(StrokeSchema, {
									color: st.color ?? 0,
									width: st.width ?? 1.0,
									opacity: st.opacity ?? 1.0,
									alignment: stringToStrokeAlignment(st.alignment ?? "center"),
									cap: StrokeCap.ROUND,
									join: StrokeJoin.ROUND,
								}),
							);

							return create(ShapeSchema, {
								id: shape.id as string,
								projectId: req.projectId,
								frameId: (shape.frameId as string) || undefined,
								parentId: (shape.parentId as string) || undefined,
								type: stringToShapeType((shape.type as string) || "rectangle"),
								name: (shape.name as string) || "Shape",
								x: (shape.x as number) || 0,
								y: (shape.y as number) || 0,
								width: (shape.width as number) || 100,
								height: (shape.height as number) || 100,
								rotation: (shape.rotation as number) || 0,
								transform: create(TransformSchema, {
									a: (shape.transformA as number) ?? 1,
									b: (shape.transformB as number) ?? 0,
									c: (shape.transformC as number) ?? 0,
									d: (shape.transformD as number) ?? 1,
									e: (shape.transformE as number) ?? 0,
									f: (shape.transformF as number) ?? 0,
								}),
								fills,
								strokes,
								opacity: (shape.opacity as number) ?? 1,
								hidden: (shape.hidden as boolean) ?? false,
								blocked: (shape.blocked as boolean) ?? false,
								sortOrder: (shape.sortOrder as number) ?? 0,
								properties: new TextEncoder().encode(
									JSON.stringify(
										(shape.properties as Record<string, unknown>) || {},
									),
								),
								createdAt: toProtoTimestamp(new Date()),
								updatedAt: toProtoTimestamp(new Date()),
							});
						});

						const state = create(CanvasStateSchema, {
							shapes: protoShapes,
							version,
							lastModified: branch.updatedAt
								? new Date(branch.updatedAt).toISOString()
								: new Date().toISOString(),
						});

						return create(GetCanvasStateResponseSchema, { state });
					}
				}
			}

			// No head commit (empty branch) - return empty state
			const state = create(CanvasStateSchema, {
				shapes: [],
				version,
				lastModified: branch.updatedAt
					? new Date(branch.updatedAt).toISOString()
					: new Date().toISOString(),
			});

			return create(GetCanvasStateResponseSchema, { state });
		} catch (error) {
			perfError = error;
			throw error;
		} finally {
			await perfSpan.finish(
				{
					source,
					shapeCount,
				},
				perfError,
			);
		}
	},

	// Sync changes from client
	async syncChanges(req): Promise<SyncChangesResponse> {
		const perfSpan = startPerfSpan("canvas.syncChanges", {
			projectId: req.projectId,
			branchId: req.branchId,
			operationCount: req.operations.length,
		});
		let needsRefresh = false;
		let refreshedShapesCount = 0;
		let perfError: unknown;

		try {
			if (!req.projectId || !req.branchId) {
				throw invalidArgument("Project ID and Branch ID are required");
			}

			// Get current server version
			const branch = await db.query.branches.findFirst({
				where: eq(schema.branches.id, req.branchId),
			});
			const serverVersion = branch?.updatedAt
				? BigInt(new Date(branch.updatedAt).getTime())
				: BigInt(0);

			// Process all operations and broadcast updates
			for (const op of req.operations) {
				const shape = await processOperation(op, req.projectId);
				const now = Date.now();

				// Broadcast the change to other subscribers
				if (op.type === OperationType.CREATE && shape) {
					const update = create(CanvasUpdateSchema, {
						update: {
							case: "shapeCreated",
							value: create(ShapeCreatedSchema, {
								shape,
								createdBy: "sync",
							}),
						},
						version: BigInt(now),
						timestamp: new Date(now).toISOString(),
					});
					broadcastUpdate(req.projectId, req.branchId, update);
				} else if (op.type === OperationType.UPDATE && shape) {
					const update = create(CanvasUpdateSchema, {
						update: {
							case: "shapeUpdated",
							value: create(ShapeUpdatedSchema, {
								shape,
								updatedBy: "sync",
							}),
						},
						version: BigInt(now),
						timestamp: new Date(now).toISOString(),
					});
					broadcastUpdate(req.projectId, req.branchId, update);
				} else if (op.type === OperationType.DELETE) {
					const update = create(CanvasUpdateSchema, {
						update: {
							case: "shapeDeleted",
							value: create(ShapeDeletedSchema, {
								shapeId: op.shapeId,
								deletedBy: "sync",
							}),
						},
						version: BigInt(now),
						timestamp: new Date(now).toISOString(),
					});
					broadcastUpdate(req.projectId, req.branchId, update);
				}
			}

			// Update branch timestamp
			const newVersion = BigInt(Date.now());
			await db
				.update(schema.branches)
				.set({ updatedAt: new Date(Number(newVersion)) })
				.where(eq(schema.branches.id, req.branchId));

			// Check if client needs full refresh
			needsRefresh = req.localVersion < serverVersion;

			if (needsRefresh) {
				const updatedShapes = await db
					.select()
					.from(schema.shapes)
					.where(eq(schema.shapes.projectId, req.projectId))
					.orderBy(asc(schema.shapes.sortOrder));
				refreshedShapesCount = updatedShapes.length;

				return create(SyncChangesResponseSchema, {
					success: true,
					serverVersion: newVersion,
					shapes: updatedShapes.map(toProtoShape),
					message: "Synced with server refresh",
				});
			}

			return create(SyncChangesResponseSchema, {
				success: true,
				serverVersion: newVersion,
				shapes: [],
				message: "Synced successfully",
			});
		} catch (error) {
			perfError = error;
			throw error;
		} finally {
			await perfSpan.finish(
				{
					needsRefresh,
					refreshedShapesCount,
				},
				perfError,
			);
		}
	},

	// Server streaming: real-time updates
	async *streamUpdates(req): AsyncGenerator<CanvasUpdate> {
		const channelKey = getChannelKey(req.projectId, req.branchId);

		// Create a subscriber callback
		const updateQueue: CanvasUpdate[] = [];
		let resolveNext: (() => void) | null = null;

		const callback = (update: CanvasUpdate) => {
			updateQueue.push(update);
			if (resolveNext) {
				resolveNext();
				resolveNext = null;
			}
		};

		// Subscribe to updates
		if (!updateSubscribers.has(channelKey)) {
			updateSubscribers.set(channelKey, new Set());
		}
		updateSubscribers.get(channelKey)?.add(callback);

		// Broadcast user joined
		const now = Date.now();
		const userJoinedUpdate = create(CanvasUpdateSchema, {
			update: {
				case: "userJoined",
				value: create(UserJoinedSchema, {
					user: create(UserPresenceSchema, {
						userId: req.userId,
						userName: req.userId, // TODO: get from auth
					}),
				}),
			},
			version: BigInt(now),
			timestamp: new Date(now).toISOString(),
		});
		broadcastUpdate(req.projectId, req.branchId, userJoinedUpdate);

		try {
			// Keep streaming until client disconnects
			while (true) {
				// Wait for updates if queue is empty
				if (updateQueue.length === 0) {
					await new Promise<void>((resolve) => {
						resolveNext = resolve;
					});
				}

				// Yield all queued updates
				while (updateQueue.length > 0) {
					const update = updateQueue.shift();
					if (update) yield update;
				}
			}
		} finally {
			// Cleanup on disconnect
			updateSubscribers.get(channelKey)?.delete(callback);

			// Broadcast user left
			const leftNow = Date.now();
			const userLeftUpdate = create(CanvasUpdateSchema, {
				update: {
					case: "userLeft",
					value: create(UserLeftSchema, { userId: req.userId }),
				},
				version: BigInt(leftNow),
				timestamp: new Date(leftNow).toISOString(),
			});
			broadcastUpdate(req.projectId, req.branchId, userLeftUpdate);
		}
	},

	// Bidirectional streaming: collaboration
	async *collaborate(requests): AsyncGenerator<CollaborateResponse> {
		let currentProjectId: string | undefined;
		let currentBranchId: string | undefined;
		let currentUserId: string | undefined;
		let channelKey: string | undefined;

		// Subscribe to channel for incoming updates from others
		const updateQueue: CanvasUpdate[] = [];
		let resolveNext: (() => void) | null = null;

		const callback = (update: CanvasUpdate) => {
			updateQueue.push(update);
			if (resolveNext) {
				resolveNext();
				resolveNext = null;
			}
		};

		try {
			for await (const msg of requests) {
				// Handle join session - use oneof pattern
				if (msg.request?.case === "join") {
					const join = msg.request.value;
					currentProjectId = join.projectId;
					currentBranchId = join.branchId;
					currentUserId = join.userId;
					channelKey = getChannelKey(currentProjectId, currentBranchId);

					if (!updateSubscribers.has(channelKey)) {
						updateSubscribers.set(channelKey, new Set());
					}
					updateSubscribers.get(channelKey)?.add(callback);

					// Register collaborator
					collaborators.set(currentUserId, {
						userId: currentUserId,
						userName: join.userName,
						projectId: currentProjectId,
						branchId: currentBranchId,
						color: join.userColor,
						selection: [],
						lastSeen: Date.now(),
					});

					// Get initial state
					const shapes = await db
						.select()
						.from(schema.shapes)
						.where(eq(schema.shapes.projectId, currentProjectId))
						.orderBy(asc(schema.shapes.sortOrder));

					const branch = await db.query.branches.findFirst({
						where: eq(schema.branches.id, currentBranchId),
					});

					const version = branch?.updatedAt
						? BigInt(new Date(branch.updatedAt).getTime())
						: BigInt(Date.now());

					// Get active users
					const activeUsers: UserPresence[] = [];
					for (const [, collab] of collaborators.entries()) {
						if (
							collab.projectId === currentProjectId &&
							collab.branchId === currentBranchId
						) {
							const cursor: CursorPosition | undefined = collab.cursor
								? create(CursorPositionSchema, {
										userId: collab.userId,
										userName: collab.userName,
										x: collab.cursor.x,
										y: collab.cursor.y,
									})
								: undefined;
							activeUsers.push(
								create(UserPresenceSchema, {
									userId: collab.userId,
									userName: collab.userName,
									color: collab.color,
									cursor,
									selectedShapeIds: collab.selection,
								}),
							);
						}
					}

					// Broadcast user joined
					const joinNow = Date.now();
					const userJoinedUpdate = create(CanvasUpdateSchema, {
						update: {
							case: "userJoined",
							value: create(UserJoinedSchema, {
								user: create(UserPresenceSchema, {
									userId: currentUserId,
									userName: join.userName,
									color: join.userColor,
								}),
							}),
						},
						version: BigInt(joinNow),
						timestamp: new Date(joinNow).toISOString(),
					});
					broadcastUpdate(currentProjectId, currentBranchId, userJoinedUpdate);

					// Send initial state
					const initialState = create(CanvasStateSchema, {
						shapes: shapes.map(toProtoShape),
						version,
						lastModified: branch?.updatedAt
							? new Date(branch.updatedAt).toISOString()
							: new Date().toISOString(),
					});

					const sessionJoined = create(SessionJoinedSchema, {
						initialState,
						activeUsers,
					});

					yield create(CollaborateResponseSchema, {
						response: {
							case: "sessionJoined",
							value: sessionJoined,
						},
					});
					continue;
				}

				// Handle leave session
				if (msg.request?.case === "leave" && currentUserId) {
					collaborators.delete(currentUserId);

					if (currentProjectId && currentBranchId) {
						const leaveNow = Date.now();
						const userLeftUpdate = create(CanvasUpdateSchema, {
							update: {
								case: "userLeft",
								value: create(UserLeftSchema, { userId: currentUserId }),
							},
							version: BigInt(leaveNow),
							timestamp: new Date(leaveNow).toISOString(),
						});
						broadcastUpdate(currentProjectId, currentBranchId, userLeftUpdate);
					}
					continue;
				}

				// Update collaborator state
				const collab = currentUserId
					? collaborators.get(currentUserId)
					: undefined;
				if (collab) {
					collab.lastSeen = Date.now();

					// Handle cursor position updates
					if (
						msg.request?.case === "cursor" &&
						currentProjectId &&
						currentBranchId
					) {
						const cursor = msg.request.value;
						collab.cursor = { x: cursor.x, y: cursor.y };

						const cursorNow = Date.now();
						const cursorPosition = create(CursorPositionSchema, {
							userId: currentUserId ?? "",
							userName: collab.userName,
							userColor: collab.color,
							x: cursor.x,
							y: cursor.y,
						});
						const cursorMoved = create(CursorMovedSchema, {
							cursor: cursorPosition,
						});
						const cursorUpdate = create(CanvasUpdateSchema, {
							update: {
								case: "cursorMoved",
								value: cursorMoved,
							},
							version: BigInt(cursorNow),
							timestamp: new Date(cursorNow).toISOString(),
						});
						broadcastUpdate(currentProjectId, currentBranchId, cursorUpdate);
					}

					// Handle selection updates
					if (
						msg.request?.case === "selection" &&
						currentProjectId &&
						currentBranchId
					) {
						const selection = msg.request.value;
						collab.selection = [...selection.shapeIds];

						const selNow = Date.now();
						const selectionChanged = create(SelectionChangedSchema, {
							userId: currentUserId ?? "",
							shapeIds: selection.shapeIds,
						});
						const selectionUpdate = create(CanvasUpdateSchema, {
							update: {
								case: "selectionChanged",
								value: selectionChanged,
							},
							version: BigInt(selNow),
							timestamp: new Date(selNow).toISOString(),
						});
						broadcastUpdate(currentProjectId, currentBranchId, selectionUpdate);
					}

					// Handle operations
					if (
						msg.request?.case === "operation" &&
						currentProjectId &&
						currentBranchId
					) {
						const operation = msg.request.value;
						const shape = await processOperation(operation, currentProjectId);

						// Update version
						const newVersion = BigInt(Date.now());
						await db
							.update(schema.branches)
							.set({ updatedAt: new Date(Number(newVersion)) })
							.where(eq(schema.branches.id, currentBranchId));

						// Broadcast the change
						const opNow = Date.now();
						if (operation.type === OperationType.CREATE && shape) {
							const shapeCreated = create(ShapeCreatedSchema, {
								shape,
								createdBy: currentUserId ?? "",
							});
							const createUpdate = create(CanvasUpdateSchema, {
								update: {
									case: "shapeCreated",
									value: shapeCreated,
								},
								version: BigInt(opNow),
								timestamp: new Date(opNow).toISOString(),
							});
							broadcastUpdate(currentProjectId, currentBranchId, createUpdate);
						} else if (operation.type === OperationType.UPDATE && shape) {
							const shapeUpdated = create(ShapeUpdatedSchema, {
								shape,
								updatedBy: currentUserId ?? "",
							});
							const updateMsg = create(CanvasUpdateSchema, {
								update: {
									case: "shapeUpdated",
									value: shapeUpdated,
								},
								version: BigInt(opNow),
								timestamp: new Date(opNow).toISOString(),
							});
							broadcastUpdate(currentProjectId, currentBranchId, updateMsg);
						} else if (operation.type === OperationType.DELETE) {
							const shapeDeleted = create(ShapeDeletedSchema, {
								shapeId: operation.shapeId,
								deletedBy: currentUserId ?? "",
							});
							const deleteUpdate = create(CanvasUpdateSchema, {
								update: {
									case: "shapeDeleted",
									value: shapeDeleted,
								},
								version: BigInt(opNow),
								timestamp: new Date(opNow).toISOString(),
							});
							broadcastUpdate(currentProjectId, currentBranchId, deleteUpdate);
						}

						// Send ack to the client
						const syncAck = create(SyncAckSchema, {
							success: true,
							version: newVersion,
						});
						yield create(CollaborateResponseSchema, {
							response: {
								case: "syncAck",
								value: syncAck,
							},
						});
					}
				}

				// Yield any pending updates from others
				while (updateQueue.length > 0) {
					const update = updateQueue.shift();
					if (update) {
						yield create(CollaborateResponseSchema, {
							response: {
								case: "update",
								value: update,
							},
						});
					}
				}
			}
		} finally {
			// Cleanup
			if (currentUserId) {
				collaborators.delete(currentUserId);
			}
			if (channelKey) {
				updateSubscribers.get(channelKey)?.delete(callback);
			}
			if (currentUserId && currentProjectId && currentBranchId) {
				const finalNow = Date.now();
				const userLeftUpdate = create(CanvasUpdateSchema, {
					update: {
						case: "userLeft",
						value: create(UserLeftSchema, { userId: currentUserId }),
					},
					version: BigInt(finalNow),
					timestamp: new Date(finalNow).toISOString(),
				});
				broadcastUpdate(currentProjectId, currentBranchId, userLeftUpdate);
			}
		}
	},

	// Restore working copy from a snapshot (branch switch)
	// Uses a transaction to ensure atomicity - either all shapes are replaced or none
	async restoreFromSnapshot(req) {
		const perfSpan = startPerfSpan("canvas.restoreFromSnapshot", {
			projectId: req.projectId,
			snapshotId: req.snapshotId,
		});
		let snapshotShapeCount = 0;
		let perfError: unknown;

		try {
			if (!req.projectId || !req.snapshotId) {
				throw invalidArgument("Project ID and Snapshot ID are required");
			}

			// Get the snapshot
			const snapshot = await db.query.snapshots.findFirst({
				where: and(
					eq(schema.snapshots.id, req.snapshotId),
					eq(schema.snapshots.projectId, req.projectId),
				),
			});

			if (!snapshot) {
				throw notFound("Snapshot not found");
			}

			// Parse shapes from snapshot
			const snapshotData = snapshot.data as {
				shapes?: Array<Record<string, unknown>>;
			};
			const snapshotShapes = snapshotData.shapes ?? [];
			snapshotShapeCount = snapshotShapes.length;

			// Use a transaction to ensure atomicity
			// This prevents partial state if the operation fails mid-way
			await db.transaction(async (tx) => {
				// Delete all existing shapes for this project
				await tx
					.delete(schema.shapes)
					.where(eq(schema.shapes.projectId, req.projectId));

				// Insert shapes from the snapshot
				if (snapshotShapes.length > 0) {
					const shapesToInsert = snapshotShapes.map(
						(shape: Record<string, unknown>) => ({
							id: shape.id as string,
							projectId: req.projectId,
							frameId: (shape.frameId as string) || null,
							parentId: (shape.parentId as string) || null,
							type: shape.type as string,
							name: shape.name as string,
							x: shape.x as number,
							y: shape.y as number,
							width: shape.width as number,
							height: shape.height as number,
							rotation: (shape.rotation as number) || 0,
							transformA: (shape.transformA as number) ?? 1,
							transformB: (shape.transformB as number) ?? 0,
							transformC: (shape.transformC as number) ?? 0,
							transformD: (shape.transformD as number) ?? 1,
							transformE: (shape.transformE as number) ?? 0,
							transformF: (shape.transformF as number) ?? 0,
							fills: (shape.fills as Array<unknown>) || [],
							strokes: (shape.strokes as Array<unknown>) || [],
							opacity: (shape.opacity as number) ?? 1,
							hidden: (shape.hidden as boolean) ?? false,
							blocked: (shape.blocked as boolean) ?? false,
							properties: (shape.properties as Record<string, unknown>) ?? {},
							sortOrder: (shape.sortOrder as number) ?? 0,
						}),
					);

					await tx.insert(schema.shapes).values(shapesToInsert);
				}
			});

			return create(RestoreFromSnapshotResponseSchema, {
				success: true,
				shapeCount: snapshotShapes.length,
				message: `Restored ${snapshotShapes.length} shapes from snapshot`,
			});
		} catch (error) {
			perfError = error;
			throw error;
		} finally {
			await perfSpan.finish({ snapshotShapeCount }, perfError);
		}
	},

	// Clear working copy (for empty branches)
	async clearWorkingCopy(req) {
		if (!req.projectId) {
			throw invalidArgument("Project ID is required");
		}

		// Delete all shapes for this project
		await db
			.delete(schema.shapes)
			.where(eq(schema.shapes.projectId, req.projectId));

		return create(ClearWorkingCopyResponseSchema, {
			success: true,
			deletedCount: 0, // We don't track exact count for simplicity
			message: "Cleared working copy",
		});
	},
};
