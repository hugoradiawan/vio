import type { ConnectRouter } from "@connectrpc/connect";
import { Code, ConnectError } from "@connectrpc/connect";
import { eq } from "drizzle-orm";
import { db, schema } from "../db";
import { Branch } from "../gen/vio/v1/branch_pb.js";
import { Timestamp as ProtoTimestamp } from "../gen/vio/v1/common_pb.js";
import { ProjectService } from "../gen/vio/v1/project_connect.js";
import {
	CreateProjectResponse,
	Frame,
	GetProjectResponse,
	ListProjectsResponse,
	Project,
	UpdateProjectResponse,
} from "../gen/vio/v1/project_pb.js";

function toProtoTimestamp(date: Date): ProtoTimestamp {
	return new ProtoTimestamp({
		millis: BigInt(date.getTime()),
	});
}

function toProtoProject(
	dbProject: typeof schema.projects.$inferSelect,
): Project {
	return new Project({
		id: dbProject.id,
		name: dbProject.name,
		description: dbProject.description ?? undefined,
		ownerId: dbProject.ownerId,
		teamId: dbProject.teamId ?? undefined,
		isPublic: dbProject.isPublic,
		defaultBranchId: dbProject.defaultBranchId ?? undefined,
		createdAt: toProtoTimestamp(new Date(dbProject.createdAt)),
		updatedAt: toProtoTimestamp(new Date(dbProject.updatedAt)),
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

function toProtoFrame(dbFrame: typeof schema.frames.$inferSelect): Frame {
	return new Frame({
		id: dbFrame.id,
		projectId: dbFrame.projectId,
		name: dbFrame.name,
		x: dbFrame.x,
		y: dbFrame.y,
		width: dbFrame.width,
		height: dbFrame.height,
		backgroundColor: dbFrame.backgroundColor ?? undefined,
		clipContent: dbFrame.clipContent,
		sortOrder: dbFrame.sortOrder,
	});
}

export function registerProjectService(router: ConnectRouter) {
	router.service(ProjectService, {
		async listProjects(req) {
			// In production, filter by ownerId from auth context
			const projects = await db.select().from(schema.projects);

			return new ListProjectsResponse({
				projects: projects.map(toProtoProject),
			});
		},

		async getProject(req) {
			const project = await db.query.projects.findFirst({
				where: eq(schema.projects.id, req.projectId),
				with: {
					branches: true,
					frames: true,
				},
			});

			if (!project) {
				throw new ConnectError("Project not found", Code.NotFound);
			}

			return new GetProjectResponse({
				project: toProtoProject(project),
				branches: project.branches.map(toProtoBranch),
				frames: project.frames.map(toProtoFrame),
			});
		},

		async createProject(req) {
			// Insert project
			const [project] = await db
				.insert(schema.projects)
				.values({
					name: req.name,
					description: req.description,
					ownerId: req.ownerId,
					teamId: req.teamId,
				})
				.returning();

			// Create default "main" branch
			const [mainBranch] = await db
				.insert(schema.branches)
				.values({
					projectId: project.id,
					name: "main",
					isDefault: true,
					createdById: req.ownerId,
				})
				.returning();

			// Update project with default branch
			await db
				.update(schema.projects)
				.set({ defaultBranchId: mainBranch.id })
				.where(eq(schema.projects.id, project.id));

			// Create initial frame
			await db.insert(schema.frames).values({
				projectId: project.id,
				name: "Frame 1",
				x: 0,
				y: 0,
				width: 800,
				height: 600,
			});

			return new CreateProjectResponse({
				project: toProtoProject({
					...project,
					defaultBranchId: mainBranch.id,
				}),
			});
		},

		async updateProject(req) {
			const updateData: Partial<typeof schema.projects.$inferInsert> = {
				updatedAt: new Date(),
			};

			if (req.name) updateData.name = req.name;
			if (req.description !== undefined)
				updateData.description = req.description;
			if (req.isPublic !== undefined) updateData.isPublic = req.isPublic;

			const [updated] = await db
				.update(schema.projects)
				.set(updateData)
				.where(eq(schema.projects.id, req.projectId))
				.returning();

			if (!updated) {
				throw new ConnectError("Project not found", Code.NotFound);
			}

			return new UpdateProjectResponse({
				project: toProtoProject(updated),
			});
		},

		async deleteProject(req) {
			const [deleted] = await db
				.update(schema.projects)
				.set({ deletedAt: new Date() })
				.where(eq(schema.projects.id, req.projectId))
				.returning();

			if (!deleted) {
				throw new ConnectError("Project not found", Code.NotFound);
			}

			// Return empty response
			return {};
		},
	});
}
