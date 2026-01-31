import { relations } from "drizzle-orm";
import {
	boolean,
	doublePrecision,
	index,
	integer,
	jsonb,
	pgTable,
	text,
	timestamp,
	uuid,
	varchar,
} from "drizzle-orm/pg-core";

// ============================================================================
// Projects - Top-level container
// ============================================================================

export const projects = pgTable(
	"projects",
	{
		id: uuid("id").primaryKey().defaultRandom(),
		name: text("name").notNull(),
		description: text("description"),
		ownerId: uuid("owner_id").notNull(),
		teamId: uuid("team_id"),
		isPublic: boolean("is_public").default(false).notNull(),
		defaultBranchId: uuid("default_branch_id"),
		createdAt: timestamp("created_at").defaultNow().notNull(),
		updatedAt: timestamp("updated_at").defaultNow().notNull(),
		deletedAt: timestamp("deleted_at"),
	},
	(table) => ({
		ownerIdx: index("projects_owner_idx").on(table.ownerId),
		teamIdx: index("projects_team_idx").on(table.teamId),
	}),
);

// ============================================================================
// Branches - Git-like branches for version control
// ============================================================================

export const branches = pgTable(
	"branches",
	{
		id: uuid("id").primaryKey().defaultRandom(),
		projectId: uuid("project_id")
			.notNull()
			.references(() => projects.id, { onDelete: "cascade" }),
		name: varchar("name", { length: 255 }).notNull(),
		description: text("description"),
		headCommitId: uuid("head_commit_id"),
		isDefault: boolean("is_default").default(false).notNull(),
		isProtected: boolean("is_protected").default(false).notNull(),
		createdById: uuid("created_by_id").notNull(),
		createdAt: timestamp("created_at").defaultNow().notNull(),
		updatedAt: timestamp("updated_at").defaultNow().notNull(),
	},
	(table) => ({
		projectIdx: index("branches_project_idx").on(table.projectId),
		nameIdx: index("branches_name_idx").on(table.projectId, table.name),
	}),
);

// ============================================================================
// Commits - Immutable snapshots of design state
// ============================================================================

export const commits = pgTable(
	"commits",
	{
		id: uuid("id").primaryKey().defaultRandom(),
		projectId: uuid("project_id")
			.notNull()
			.references(() => projects.id, { onDelete: "cascade" }),
		branchId: uuid("branch_id")
			.notNull()
			.references(() => branches.id, { onDelete: "cascade" }),
		parentId: uuid("parent_id"),
		message: text("message").notNull(),
		authorId: uuid("author_id").notNull(),
		snapshotId: uuid("snapshot_id").notNull(),
		createdAt: timestamp("created_at").defaultNow().notNull(),
	},
	(table) => ({
		projectIdx: index("commits_project_idx").on(table.projectId),
		branchIdx: index("commits_branch_idx").on(table.branchId),
		parentIdx: index("commits_parent_idx").on(table.parentId),
	}),
);

// ============================================================================
// Snapshots - Complete design state at a point in time
// ============================================================================

export const snapshots = pgTable("snapshots", {
	id: uuid("id").primaryKey().defaultRandom(),
	projectId: uuid("project_id")
		.notNull()
		.references(() => projects.id, { onDelete: "cascade" }),
	data: jsonb("data").notNull(), // Serialized canvas state
	createdAt: timestamp("created_at").defaultNow().notNull(),
});

// ============================================================================
// Frames - Artboard containers
// ============================================================================

export const frames = pgTable(
	"frames",
	{
		id: uuid("id").primaryKey().defaultRandom(),
		projectId: uuid("project_id")
			.notNull()
			.references(() => projects.id, { onDelete: "cascade" }),
		name: text("name").notNull(),
		x: doublePrecision("x").notNull().default(0),
		y: doublePrecision("y").notNull().default(0),
		width: doublePrecision("width").notNull().default(800),
		height: doublePrecision("height").notNull().default(600),
		backgroundColor: varchar("background_color", { length: 9 }),
		clipContent: boolean("clip_content").default(true).notNull(),
		sortOrder: integer("sort_order").default(0).notNull(),
		createdAt: timestamp("created_at").defaultNow().notNull(),
		updatedAt: timestamp("updated_at").defaultNow().notNull(),
	},
	(table) => ({
		projectIdx: index("frames_project_idx").on(table.projectId),
	}),
);

// ============================================================================
// Shapes - All shape types
// ============================================================================

export const shapes = pgTable(
	"shapes",
	{
		id: uuid("id").primaryKey().defaultRandom(),
		projectId: uuid("project_id")
			.notNull()
			.references(() => projects.id, { onDelete: "cascade" }),
		// frameId references another shape with type='frame', not the frames table
		// This is a soft reference to support the flat shape hierarchy
		frameId: uuid("frame_id"),
		parentId: uuid("parent_id"),
		type: varchar("type", { length: 50 }).notNull(), // rectangle, ellipse, path, text, etc.
		name: text("name").notNull(),

		// Transform (6-parameter matrix)
		transformA: doublePrecision("transform_a").default(1).notNull(),
		transformB: doublePrecision("transform_b").default(0).notNull(),
		transformC: doublePrecision("transform_c").default(0).notNull(),
		transformD: doublePrecision("transform_d").default(1).notNull(),
		transformE: doublePrecision("transform_e").default(0).notNull(),
		transformF: doublePrecision("transform_f").default(0).notNull(),

		// Bounds
		x: doublePrecision("x").notNull(),
		y: doublePrecision("y").notNull(),
		width: doublePrecision("width").notNull(),
		height: doublePrecision("height").notNull(),
		rotation: doublePrecision("rotation").default(0).notNull(),

		// Visual properties
		fills: jsonb("fills").default([]).notNull(),
		strokes: jsonb("strokes").default([]).notNull(),
		opacity: doublePrecision("opacity").default(1).notNull(),

		// Shape-specific properties stored as JSON
		properties: jsonb("properties").default({}).notNull(),

		// State
		hidden: boolean("hidden").default(false).notNull(),
		blocked: boolean("blocked").default(false).notNull(),
		sortOrder: integer("sort_order").default(0).notNull(),

		createdAt: timestamp("created_at").defaultNow().notNull(),
		updatedAt: timestamp("updated_at").defaultNow().notNull(),
	},
	(table) => ({
		projectIdx: index("shapes_project_idx").on(table.projectId),
		frameIdx: index("shapes_frame_idx").on(table.frameId),
		parentIdx: index("shapes_parent_idx").on(table.parentId),
		typeIdx: index("shapes_type_idx").on(table.type),
	}),
);

// ============================================================================
// Pull Requests - Design review workflow
// ============================================================================

export const pullRequests = pgTable(
	"pull_requests",
	{
		id: uuid("id").primaryKey().defaultRandom(),
		projectId: uuid("project_id")
			.notNull()
			.references(() => projects.id, { onDelete: "cascade" }),
		sourceBranchId: uuid("source_branch_id")
			.notNull()
			.references(() => branches.id),
		targetBranchId: uuid("target_branch_id")
			.notNull()
			.references(() => branches.id),
		title: text("title").notNull(),
		description: text("description"),
		status: varchar("status", { length: 20 }).default("open").notNull(), // open, merged, closed
		authorId: uuid("author_id").notNull(),
		reviewers: jsonb("reviewers").default([]).notNull(),
		createdAt: timestamp("created_at").defaultNow().notNull(),
		updatedAt: timestamp("updated_at").defaultNow().notNull(),
		mergedAt: timestamp("merged_at"),
		closedAt: timestamp("closed_at"),
	},
	(table) => ({
		projectIdx: index("prs_project_idx").on(table.projectId),
		statusIdx: index("prs_status_idx").on(table.status),
	}),
);

// ============================================================================
// Comments - Design feedback on shapes/frames
// ============================================================================

export const comments = pgTable(
	"comments",
	{
		id: uuid("id").primaryKey().defaultRandom(),
		projectId: uuid("project_id")
			.notNull()
			.references(() => projects.id, { onDelete: "cascade" }),
		pullRequestId: uuid("pull_request_id").references(() => pullRequests.id, {
			onDelete: "cascade",
		}),
		shapeId: uuid("shape_id").references(() => shapes.id, {
			onDelete: "cascade",
		}),
		parentId: uuid("parent_id"),
		authorId: uuid("author_id").notNull(),
		content: text("content").notNull(),
		x: doublePrecision("x"), // Position on canvas for pin comments
		y: doublePrecision("y"),
		resolved: boolean("resolved").default(false).notNull(),
		createdAt: timestamp("created_at").defaultNow().notNull(),
		updatedAt: timestamp("updated_at").defaultNow().notNull(),
	},
	(table) => ({
		projectIdx: index("comments_project_idx").on(table.projectId),
		shapeIdx: index("comments_shape_idx").on(table.shapeId),
		prIdx: index("comments_pr_idx").on(table.pullRequestId),
	}),
);

// ============================================================================
// Relations
// ============================================================================

export const projectsRelations = relations(projects, ({ many, one }) => ({
	branches: many(branches),
	commits: many(commits),
	frames: many(frames),
	shapes: many(shapes),
	pullRequests: many(pullRequests),
	defaultBranch: one(branches, {
		fields: [projects.defaultBranchId],
		references: [branches.id],
	}),
}));

export const branchesRelations = relations(branches, ({ one, many }) => ({
	project: one(projects, {
		fields: [branches.projectId],
		references: [projects.id],
	}),
	commits: many(commits),
	headCommit: one(commits, {
		fields: [branches.headCommitId],
		references: [commits.id],
	}),
}));

export const commitsRelations = relations(commits, ({ one }) => ({
	project: one(projects, {
		fields: [commits.projectId],
		references: [projects.id],
	}),
	branch: one(branches, {
		fields: [commits.branchId],
		references: [branches.id],
	}),
	parent: one(commits, {
		fields: [commits.parentId],
		references: [commits.id],
	}),
	snapshot: one(snapshots, {
		fields: [commits.snapshotId],
		references: [snapshots.id],
	}),
}));

export const framesRelations = relations(frames, ({ one, many }) => ({
	project: one(projects, {
		fields: [frames.projectId],
		references: [projects.id],
	}),
	shapes: many(shapes),
}));

export const shapesRelations = relations(shapes, ({ one, many }) => ({
	project: one(projects, {
		fields: [shapes.projectId],
		references: [projects.id],
	}),
	frame: one(frames, {
		fields: [shapes.frameId],
		references: [frames.id],
	}),
	parent: one(shapes, {
		fields: [shapes.parentId],
		references: [shapes.id],
	}),
	children: many(shapes),
	comments: many(comments),
}));
