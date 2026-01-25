/**
 * Canvas service implementation for real-time collaboration.
 * Handles canvas state, sync, and bidirectional streaming for presence.
 */

import { and, asc, eq } from "drizzle-orm";
import { ServerError, Status } from "nice-grpc";
import { db, schema } from "../db";
import type {
  CanvasServiceImplementation,
  CanvasState,
  CanvasUpdate,
  CollaborateResponse,
  CursorMoved,
  CursorPosition,
  GetCanvasStateResponse,
  SelectionChanged,
  SessionJoined,
  ShapeCreated,
  ShapeDeleted,
  ShapeUpdated,
  SyncAck,
  SyncChangesResponse,
  SyncOperation,
  UserJoined,
  UserLeft,
  UserPresence,
} from "../gen/vio/v1/canvas.js";
import { OperationType } from "../gen/vio/v1/canvas.js";
import type {
  Fill,
  Stroke,
  Timestamp,
} from "../gen/vio/v1/common.js";
import {
  StrokeAlignment,
  StrokeCap,
  StrokeJoin,
} from "../gen/vio/v1/common.js";
import {
  ShapeType,
  type Shape,
} from "../gen/vio/v1/shape.js";

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
      const update: CanvasUpdate = {
        update: {
          $case: "userLeft",
          userLeft: { userId: id } as UserLeft,
        },
        version: BigInt(now),
        timestamp: new Date(now).toISOString(),
      };
      broadcastUpdate(collab.projectId, collab.branchId, update);
    }
  }
}, 30_000);

// ============================================================================
// Helper Functions - Enum conversions
// ============================================================================

function stringToShapeType(type: string): ShapeType {
  const mapping: Record<string, ShapeType> = {
    rectangle: ShapeType.SHAPE_TYPE_RECTANGLE,
    ellipse: ShapeType.SHAPE_TYPE_ELLIPSE,
    path: ShapeType.SHAPE_TYPE_PATH,
    text: ShapeType.SHAPE_TYPE_TEXT,
    frame: ShapeType.SHAPE_TYPE_FRAME,
    group: ShapeType.SHAPE_TYPE_GROUP,
    image: ShapeType.SHAPE_TYPE_IMAGE,
    svg: ShapeType.SHAPE_TYPE_SVG,
    bool: ShapeType.SHAPE_TYPE_BOOL,
  };
  return mapping[type.toLowerCase()] ?? ShapeType.SHAPE_TYPE_UNSPECIFIED;
}

function shapeTypeToString(type: ShapeType): string {
  switch (type) {
    case ShapeType.SHAPE_TYPE_RECTANGLE:
      return "rectangle";
    case ShapeType.SHAPE_TYPE_ELLIPSE:
      return "ellipse";
    case ShapeType.SHAPE_TYPE_PATH:
      return "path";
    case ShapeType.SHAPE_TYPE_TEXT:
      return "text";
    case ShapeType.SHAPE_TYPE_FRAME:
      return "frame";
    case ShapeType.SHAPE_TYPE_GROUP:
      return "group";
    case ShapeType.SHAPE_TYPE_IMAGE:
      return "image";
    case ShapeType.SHAPE_TYPE_SVG:
      return "svg";
    case ShapeType.SHAPE_TYPE_BOOL:
      return "bool";
    default:
      return "unspecified";
  }
}

function stringToStrokeAlignment(alignment: string): StrokeAlignment {
  const mapping: Record<string, StrokeAlignment> = {
    center: StrokeAlignment.STROKE_ALIGNMENT_CENTER,
    inside: StrokeAlignment.STROKE_ALIGNMENT_INSIDE,
    outside: StrokeAlignment.STROKE_ALIGNMENT_OUTSIDE,
  };
  return mapping[alignment.toLowerCase()] ?? StrokeAlignment.STROKE_ALIGNMENT_CENTER;
}

function strokeAlignmentToString(alignment: StrokeAlignment): string {
  switch (alignment) {
    case StrokeAlignment.STROKE_ALIGNMENT_CENTER:
      return "center";
    case StrokeAlignment.STROKE_ALIGNMENT_INSIDE:
      return "inside";
    case StrokeAlignment.STROKE_ALIGNMENT_OUTSIDE:
      return "outside";
    default:
      return "center";
  }
}

function toProtoTimestamp(date: Date): Timestamp {
  return { millis: BigInt(date.getTime()) };
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
  const fills: Fill[] = ((dbShape.fills as DbFill[]) || []).map((f) => ({
    color: f.color ?? 0,
    opacity: f.opacity ?? 1.0,
  }));

  const strokes: Stroke[] = ((dbShape.strokes as DbStroke[]) || []).map((st) => ({
    color: st.color ?? 0,
    width: st.width ?? 1.0,
    opacity: st.opacity ?? 1.0,
    alignment: stringToStrokeAlignment(st.alignment ?? "center"),
    cap: StrokeCap.STROKE_CAP_ROUND,
    join: StrokeJoin.STROKE_JOIN_ROUND,
  }));

  return {
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
    transform: {
      a: dbShape.transformA,
      b: dbShape.transformB,
      c: dbShape.transformC,
      d: dbShape.transformD,
      e: dbShape.transformE,
      f: dbShape.transformF,
    },
    fills,
    strokes,
    opacity: dbShape.opacity,
    hidden: dbShape.hidden,
    blocked: dbShape.blocked,
    sortOrder: dbShape.sortOrder,
    properties: new TextEncoder().encode(
      JSON.stringify(dbShape.properties || {})
    ),
    createdAt: toProtoTimestamp(new Date(dbShape.createdAt)),
    updatedAt: toProtoTimestamp(new Date(dbShape.updatedAt)),
  };
}

async function processOperation(
  op: SyncOperation,
  projectId: string,
): Promise<Shape | null> {
  try {
    const opType = op.type;

    if (opType === OperationType.OPERATION_TYPE_CREATE) {
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
            properties:
              op.shape.properties.length > 0
                ? JSON.parse(new TextDecoder().decode(op.shape.properties))
                : {},
            sortOrder: op.shape.sortOrder ?? 0,
          })
          .returning();
        return toProtoShape(created);
      }
    } else if (opType === OperationType.OPERATION_TYPE_UPDATE) {
      if (op.shape) {
        const updateData: Record<string, unknown> = { updatedAt: new Date() };
        if (op.shape.frameId !== undefined)
          updateData.frameId = op.shape.frameId || null;
        if (op.shape.parentId !== undefined)
          updateData.parentId = op.shape.parentId || null;
        if (op.shape.type !== ShapeType.SHAPE_TYPE_UNSPECIFIED)
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
          updateData.properties = JSON.parse(
            new TextDecoder().decode(op.shape.properties)
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
    } else if (opType === OperationType.OPERATION_TYPE_DELETE) {
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

export const canvasServiceImpl: CanvasServiceImplementation = {
  // Get current canvas state
  async getCanvasState(req): Promise<GetCanvasStateResponse> {
    if (!req.projectId || !req.branchId) {
      throw new ServerError(
        Status.INVALID_ARGUMENT,
        "Project ID and Branch ID are required",
      );
    }

    // Verify project exists
    const project = await db.query.projects.findFirst({
      where: eq(schema.projects.id, req.projectId),
    });

    if (!project) {
      throw new ServerError(Status.NOT_FOUND, "Project not found");
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

    const state: CanvasState = {
      shapes: shapes.map(toProtoShape),
      version,
      lastModified: branch?.updatedAt
        ? new Date(branch.updatedAt).toISOString()
        : new Date().toISOString(),
    };

    return { state };
  },

  // Sync changes from client
  async syncChanges(req): Promise<SyncChangesResponse> {
    if (!req.projectId || !req.branchId) {
      throw new ServerError(
        Status.INVALID_ARGUMENT,
        "Project ID and Branch ID are required",
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
      if (op.type === OperationType.OPERATION_TYPE_CREATE && shape) {
        const update: CanvasUpdate = {
          update: {
            $case: "shapeCreated",
            shapeCreated: {
              shape,
              createdBy: "sync",
            } as ShapeCreated,
          },
          version: BigInt(now),
          timestamp: new Date(now).toISOString(),
        };
        broadcastUpdate(req.projectId, req.branchId, update);
      } else if (op.type === OperationType.OPERATION_TYPE_UPDATE && shape) {
        const update: CanvasUpdate = {
          update: {
            $case: "shapeUpdated",
            shapeUpdated: {
              shape,
              updatedBy: "sync",
            } as ShapeUpdated,
          },
          version: BigInt(now),
          timestamp: new Date(now).toISOString(),
        };
        broadcastUpdate(req.projectId, req.branchId, update);
      } else if (op.type === OperationType.OPERATION_TYPE_DELETE) {
        const update: CanvasUpdate = {
          update: {
            $case: "shapeDeleted",
            shapeDeleted: {
              shapeId: op.shapeId,
              deletedBy: "sync",
            } as ShapeDeleted,
          },
          version: BigInt(now),
          timestamp: new Date(now).toISOString(),
        };
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
    const needsRefresh = req.localVersion < serverVersion;

    if (needsRefresh) {
      const updatedShapes = await db
        .select()
        .from(schema.shapes)
        .where(eq(schema.shapes.projectId, req.projectId))
        .orderBy(asc(schema.shapes.sortOrder));

      return {
        success: true,
        serverVersion: newVersion,
        shapes: updatedShapes.map(toProtoShape),
        message: "Synced with server refresh",
      };
    }

    return {
      success: true,
      serverVersion: newVersion,
      shapes: [],
      message: "Synced successfully",
    };
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
    const userJoinedUpdate: CanvasUpdate = {
      update: {
        $case: "userJoined",
        userJoined: {
          user: {
            userId: req.userId,
            userName: req.userId, // TODO: get from auth
          } as UserPresence,
        } as UserJoined,
      },
      version: BigInt(now),
      timestamp: new Date(now).toISOString(),
    };
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
      const userLeftUpdate: CanvasUpdate = {
        update: {
          $case: "userLeft",
          userLeft: { userId: req.userId } as UserLeft,
        },
        version: BigInt(leftNow),
        timestamp: new Date(leftNow).toISOString(),
      };
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
        if (msg.request?.$case === "join") {
          const join = msg.request.join;
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
                ? {
                    userId: collab.userId,
                    userName: collab.userName,
                    x: collab.cursor.x,
                    y: collab.cursor.y,
                  }
                : undefined;
              activeUsers.push({
                userId: collab.userId,
                userName: collab.userName,
                color: collab.color,
                cursor,
                selectedShapeIds: collab.selection,
              });
            }
          }

          // Broadcast user joined
          const joinNow = Date.now();
          const userJoinedUpdate: CanvasUpdate = {
            update: {
              $case: "userJoined",
              userJoined: {
                user: {
                  userId: currentUserId,
                  userName: join.userName,
                  color: join.userColor,
                },
              } as UserJoined,
            },
            version: BigInt(joinNow),
            timestamp: new Date(joinNow).toISOString(),
          };
          broadcastUpdate(currentProjectId, currentBranchId, userJoinedUpdate);

          // Send initial state
          const initialState: CanvasState = {
            shapes: shapes.map(toProtoShape),
            version,
            lastModified: branch?.updatedAt
              ? new Date(branch.updatedAt).toISOString()
              : new Date().toISOString(),
          };

          const sessionJoined: SessionJoined = {
            initialState,
            activeUsers,
          };

          yield {
            response: {
              $case: "sessionJoined",
              sessionJoined,
            },
          };
          continue;
        }

        // Handle leave session
        if (msg.request?.$case === "leave" && currentUserId) {
          collaborators.delete(currentUserId);

          if (currentProjectId && currentBranchId) {
            const leaveNow = Date.now();
            const userLeftUpdate: CanvasUpdate = {
              update: {
                $case: "userLeft",
                userLeft: { userId: currentUserId },
              },
              version: BigInt(leaveNow),
              timestamp: new Date(leaveNow).toISOString(),
            };
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
            msg.request?.$case === "cursor" &&
            currentProjectId &&
            currentBranchId
          ) {
            const cursor = msg.request.cursor;
            collab.cursor = { x: cursor.x, y: cursor.y };

            const cursorNow = Date.now();
            const cursorPosition: CursorPosition = {
              userId: currentUserId ?? "",
              userName: collab.userName,
              userColor: collab.color,
              x: cursor.x,
              y: cursor.y,
            };
            const cursorMoved: CursorMoved = { cursor: cursorPosition };
            const cursorUpdate: CanvasUpdate = {
              update: {
                $case: "cursorMoved",
                cursorMoved,
              },
              version: BigInt(cursorNow),
              timestamp: new Date(cursorNow).toISOString(),
            };
            broadcastUpdate(currentProjectId, currentBranchId, cursorUpdate);
          }

          // Handle selection updates
          if (
            msg.request?.$case === "selection" &&
            currentProjectId &&
            currentBranchId
          ) {
            const selection = msg.request.selection;
            collab.selection = [...selection.shapeIds];

            const selNow = Date.now();
            const selectionChanged: SelectionChanged = {
              userId: currentUserId ?? "",
              shapeIds: selection.shapeIds,
            };
            const selectionUpdate: CanvasUpdate = {
              update: {
                $case: "selectionChanged",
                selectionChanged,
              },
              version: BigInt(selNow),
              timestamp: new Date(selNow).toISOString(),
            };
            broadcastUpdate(currentProjectId, currentBranchId, selectionUpdate);
          }

          // Handle operations
          if (
            msg.request?.$case === "operation" &&
            currentProjectId &&
            currentBranchId
          ) {
            const operation = msg.request.operation;
            const shape = await processOperation(operation, currentProjectId);

            // Update version
            const newVersion = BigInt(Date.now());
            await db
              .update(schema.branches)
              .set({ updatedAt: new Date(Number(newVersion)) })
              .where(eq(schema.branches.id, currentBranchId));

            // Broadcast the change
            const opNow = Date.now();
            if (operation.type === OperationType.OPERATION_TYPE_CREATE && shape) {
              const shapeCreated: ShapeCreated = {
                shape,
                createdBy: currentUserId ?? "",
              };
              const createUpdate: CanvasUpdate = {
                update: {
                  $case: "shapeCreated",
                  shapeCreated,
                },
                version: BigInt(opNow),
                timestamp: new Date(opNow).toISOString(),
              };
              broadcastUpdate(currentProjectId, currentBranchId, createUpdate);
            } else if (operation.type === OperationType.OPERATION_TYPE_UPDATE && shape) {
              const shapeUpdated: ShapeUpdated = {
                shape,
                updatedBy: currentUserId ?? "",
              };
              const updateMsg: CanvasUpdate = {
                update: {
                  $case: "shapeUpdated",
                  shapeUpdated,
                },
                version: BigInt(opNow),
                timestamp: new Date(opNow).toISOString(),
              };
              broadcastUpdate(currentProjectId, currentBranchId, updateMsg);
            } else if (operation.type === OperationType.OPERATION_TYPE_DELETE) {
              const shapeDeleted: ShapeDeleted = {
                shapeId: operation.shapeId,
                deletedBy: currentUserId ?? "",
              };
              const deleteUpdate: CanvasUpdate = {
                update: {
                  $case: "shapeDeleted",
                  shapeDeleted,
                },
                version: BigInt(opNow),
                timestamp: new Date(opNow).toISOString(),
              };
              broadcastUpdate(currentProjectId, currentBranchId, deleteUpdate);
            }

            // Send ack to the client
            const syncAck: SyncAck = {
              success: true,
              version: newVersion,
            };
            yield {
              response: {
                $case: "syncAck",
                syncAck,
              },
            };
          }
        }

        // Yield any pending updates from others
        while (updateQueue.length > 0) {
          const update = updateQueue.shift();
          if (update) {
            yield {
              response: {
                $case: "update",
                update,
              },
            };
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
        const userLeftUpdate: CanvasUpdate = {
          update: {
            $case: "userLeft",
            userLeft: { userId: currentUserId },
          },
          version: BigInt(finalNow),
          timestamp: new Date(finalNow).toISOString(),
        };
        broadcastUpdate(currentProjectId, currentBranchId, userLeftUpdate);
      }
    }
  },
};
