import type { ConnectRouter } from "@connectrpc/connect";
import { Code, ConnectError } from "@connectrpc/connect";
import { and, asc, eq } from "drizzle-orm";
import { db, schema } from "../db";
import { CanvasService } from "../gen/vio/v1/canvas_connect.js";
import {
	CanvasState,
	CanvasUpdate,
	CollaborateResponse,
	CursorMoved,
	CursorPosition,
	GetCanvasStateResponse,
	OperationType,
	SelectionChanged,
	SessionJoined,
	ShapeCreated,
	ShapeDeleted,
	ShapeUpdated,
	SyncAck,
	SyncChangesResponse,
	UserJoined,
	UserLeft,
	UserPresence,
	type SyncOperation,
} from "../gen/vio/v1/canvas_pb.js";
import {
	Fill,
	Timestamp as ProtoTimestamp,
	Stroke,
	StrokeAlignment,
	Transform,
} from "../gen/vio/v1/common_pb.js";
import { Shape, ShapeType } from "../gen/vio/v1/shape_pb.js";

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
			const update = new CanvasUpdate({
				update: {
					case: "userLeft",
					value: new UserLeft({ userId: id }),
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
	const mapping: Record<ShapeType, string> = {
		[ShapeType.UNSPECIFIED]: "unspecified",
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
	return mapping[type] ?? "unspecified";
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
	const mapping: Record<StrokeAlignment, string> = {
		[StrokeAlignment.UNSPECIFIED]: "center",
		[StrokeAlignment.CENTER]: "center",
		[StrokeAlignment.INSIDE]: "inside",
		[StrokeAlignment.OUTSIDE]: "outside",
	};
	return mapping[alignment] ?? "center";
}

function toProtoTimestamp(date: Date): ProtoTimestamp {
	return new ProtoTimestamp({
		millis: BigInt(date.getTime()),
	});
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
						fills: op.shape.fills.map((f) => ({
							color: f.color,
							opacity: f.opacity,
						})),
						strokes: op.shape.strokes.map((s) => ({
							color: s.color,
							width: s.width,
							opacity: s.opacity,
							alignment: strokeAlignmentToString(s.alignment),
						})),
						opacity: op.shape.opacity ?? 1,
						hidden: op.shape.hidden ?? false,
						blocked: op.shape.blocked ?? false,
						properties: op.shape.properties.length > 0
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
					updateData.fills = op.shape.fills.map((f) => ({
						color: f.color,
						opacity: f.opacity,
					}));
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
					updateData.properties = JSON.parse(new TextDecoder().decode(op.shape.properties));
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
// Service Registration
// ============================================================================

export function registerCanvasService(router: ConnectRouter) {
	router.service(CanvasService, {
		// Get current canvas state
		async getCanvasState(req) {
			if (!req.projectId || !req.branchId) {
				throw new ConnectError(
					"Project ID and Branch ID are required",
					Code.InvalidArgument,
				);
			}

			// Verify project exists
			const project = await db.query.projects.findFirst({
				where: eq(schema.projects.id, req.projectId),
			});

			if (!project) {
				throw new ConnectError("Project not found", Code.NotFound);
			}

			// Get shapes for project
			const shapes = await db
				.select()
				.from(schema.shapes)
				.where(eq(schema.shapes.projectId, req.projectId))
				.orderBy(asc(schema.shapes.sortOrder));

			// Get branch for version info
			const branch = await db.query.branches.findFirst({
				where: eq(schema.branches.id, req.branchId),
			});

			const version = branch?.updatedAt
				? BigInt(new Date(branch.updatedAt).getTime())
				: BigInt(Date.now());

			return new GetCanvasStateResponse({
				state: new CanvasState({
					shapes: shapes.map(toProtoShape),
					version,
					lastModified: branch?.updatedAt
						? new Date(branch.updatedAt).toISOString()
						: new Date().toISOString(),
				}),
			});
		},

		// Sync changes from client
		async syncChanges(req) {
			if (!req.projectId || !req.branchId) {
				throw new ConnectError(
					"Project ID and Branch ID are required",
					Code.InvalidArgument,
				);
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
					broadcastUpdate(
						req.projectId,
						req.branchId,
						new CanvasUpdate({
							update: {
								case: "shapeCreated",
								value: new ShapeCreated({
									shape,
									createdBy: "sync",
								}),
							},
							version: BigInt(now),
							timestamp: new Date(now).toISOString(),
						}),
					);
				} else if (op.type === OperationType.UPDATE && shape) {
					broadcastUpdate(
						req.projectId,
						req.branchId,
						new CanvasUpdate({
							update: {
								case: "shapeUpdated",
								value: new ShapeUpdated({
									shape,
									updatedBy: "sync",
								}),
							},
							version: BigInt(now),
							timestamp: new Date(now).toISOString(),
						}),
					);
				} else if (op.type === OperationType.DELETE) {
					broadcastUpdate(
						req.projectId,
						req.branchId,
						new CanvasUpdate({
							update: {
								case: "shapeDeleted",
								value: new ShapeDeleted({
									shapeId: op.shapeId,
									deletedBy: "sync",
								}),
							},
							version: BigInt(now),
							timestamp: new Date(now).toISOString(),
						}),
					);
				}
			}

			// Update branch timestamp
			const newVersion = BigInt(Date.now());
			await db
				.update(schema.branches)
				.set({ updatedAt: new Date(Number(newVersion)) })
				.where(eq(schema.branches.id, req.branchId));

			// Check if client needs full refresh
			const needsRefresh = req.localVersion < serverVersion;

			if (needsRefresh) {
				const updatedShapes = await db
					.select()
					.from(schema.shapes)
					.where(eq(schema.shapes.projectId, req.projectId))
					.orderBy(asc(schema.shapes.sortOrder));

				return new SyncChangesResponse({
					success: true,
					serverVersion: newVersion,
					shapes: updatedShapes.map(toProtoShape),
					message: "Synced with server refresh",
				});
			}

			return new SyncChangesResponse({
				success: true,
				serverVersion: newVersion,
				message: "Synced successfully",
			});
		},

		// Server streaming: real-time updates
		async *streamUpdates(req) {
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
			broadcastUpdate(
				req.projectId,
				req.branchId,
				new CanvasUpdate({
					update: {
						case: "userJoined",
						value: new UserJoined({
							user: new UserPresence({
								userId: req.userId,
								userName: req.userId, // TODO: get from auth
							}),
						}),
					},
					version: BigInt(now),
					timestamp: new Date(now).toISOString(),
				}),
			);

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
				broadcastUpdate(
					req.projectId,
					req.branchId,
					new CanvasUpdate({
						update: {
							case: "userLeft",
							value: new UserLeft({ userId: req.userId }),
						},
						version: BigInt(leftNow),
						timestamp: new Date(leftNow).toISOString(),
					}),
				);
			}
		},

		// Bidirectional streaming: collaboration
		async *collaborate(requests) {
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
					if (msg.request.case === "join") {
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
								activeUsers.push(
									new UserPresence({
										userId: collab.userId,
										userName: collab.userName,
										color: collab.color,
										cursor: collab.cursor
											? new CursorPosition({
													userId: collab.userId,
													userName: collab.userName,
													x: collab.cursor.x,
													y: collab.cursor.y,
												})
											: undefined,
										selectedShapeIds: collab.selection,
									}),
								);
							}
						}

						// Broadcast user joined
						const joinNow = Date.now();
						broadcastUpdate(
							currentProjectId,
							currentBranchId,
							new CanvasUpdate({
								update: {
									case: "userJoined",
									value: new UserJoined({
										user: new UserPresence({
											userId: currentUserId,
											userName: join.userName,
											color: join.userColor,
										}),
									}),
								},
								version: BigInt(joinNow),
								timestamp: new Date(joinNow).toISOString(),
							}),
						);

						// Send initial state
						yield new CollaborateResponse({
							response: {
								case: "sessionJoined",
								value: new SessionJoined({
									initialState: new CanvasState({
										shapes: shapes.map(toProtoShape),
										version,
										lastModified: branch?.updatedAt
											? new Date(branch.updatedAt).toISOString()
											: new Date().toISOString(),
									}),
									activeUsers,
								}),
							},
						});
						continue;
					}

					// Handle leave session
					if (msg.request.case === "leave" && currentUserId) {
						collaborators.delete(currentUserId);

						if (currentProjectId && currentBranchId) {
							const leaveNow = Date.now();
							broadcastUpdate(
								currentProjectId,
								currentBranchId,
								new CanvasUpdate({
									update: {
										case: "userLeft",
										value: new UserLeft({ userId: currentUserId }),
									},
									version: BigInt(leaveNow),
									timestamp: new Date(leaveNow).toISOString(),
								}),
							);
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
							msg.request.case === "cursor" &&
							currentProjectId &&
							currentBranchId
						) {
							const cursor = msg.request.value;
							collab.cursor = { x: cursor.x, y: cursor.y };

							const cursorNow = Date.now();
							broadcastUpdate(
								currentProjectId,
								currentBranchId,
								new CanvasUpdate({
									update: {
										case: "cursorMoved",
										value: new CursorMoved({
											cursor: new CursorPosition({
												userId: currentUserId ?? "",
												userName: collab.userName,
												userColor: collab.color,
												x: cursor.x,
												y: cursor.y,
											}),
										}),
									},
									version: BigInt(cursorNow),
									timestamp: new Date(cursorNow).toISOString(),
								}),
							);
						}

						// Handle selection updates
						if (
							msg.request.case === "selection" &&
							currentProjectId &&
							currentBranchId
						) {
							const selection = msg.request.value;
							collab.selection = [...selection.shapeIds];

							const selNow = Date.now();
							broadcastUpdate(
								currentProjectId,
								currentBranchId,
								new CanvasUpdate({
									update: {
										case: "selectionChanged",
										value: new SelectionChanged({
											userId: currentUserId ?? "",
											shapeIds: selection.shapeIds,
										}),
									},
									version: BigInt(selNow),
									timestamp: new Date(selNow).toISOString(),
								}),
							);
						}

						// Handle operations
						if (
							msg.request.case === "operation" &&
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
								broadcastUpdate(
									currentProjectId,
									currentBranchId,
									new CanvasUpdate({
										update: {
											case: "shapeCreated",
											value: new ShapeCreated({
												shape,
												createdBy: currentUserId ?? "",
											}),
										},
										version: BigInt(opNow),
										timestamp: new Date(opNow).toISOString(),
									}),
								);
							} else if (operation.type === OperationType.UPDATE && shape) {
								broadcastUpdate(
									currentProjectId,
									currentBranchId,
									new CanvasUpdate({
										update: {
											case: "shapeUpdated",
											value: new ShapeUpdated({
												shape,
												updatedBy: currentUserId ?? "",
											}),
										},
										version: BigInt(opNow),
										timestamp: new Date(opNow).toISOString(),
									}),
								);
							} else if (operation.type === OperationType.DELETE) {
								broadcastUpdate(
									currentProjectId,
									currentBranchId,
									new CanvasUpdate({
										update: {
											case: "shapeDeleted",
											value: new ShapeDeleted({
												shapeId: operation.shapeId,
												deletedBy: currentUserId ?? "",
											}),
										},
										version: BigInt(opNow),
										timestamp: new Date(opNow).toISOString(),
									}),
								);
							}

							// Send ack to the client
							yield new CollaborateResponse({
								response: {
									case: "syncAck",
									value: new SyncAck({
										success: true,
										version: newVersion,
									}),
								},
							});
						}
					}

					// Yield any pending updates from others
					while (updateQueue.length > 0) {
						const update = updateQueue.shift();
						if (update) {
							yield new CollaborateResponse({
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
					broadcastUpdate(
						currentProjectId,
						currentBranchId,
						new CanvasUpdate({
							update: {
								case: "userLeft",
								value: new UserLeft({ userId: currentUserId }),
							},
							version: BigInt(finalNow),
							timestamp: new Date(finalNow).toISOString(),
						}),
					);
				}
			}
		},
	});
}
