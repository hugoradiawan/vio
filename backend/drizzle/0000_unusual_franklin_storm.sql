CREATE TABLE "branches" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"project_id" uuid NOT NULL,
	"name" varchar(255) NOT NULL,
	"description" text,
	"head_commit_id" uuid,
	"is_default" boolean DEFAULT false NOT NULL,
	"is_protected" boolean DEFAULT false NOT NULL,
	"created_by_id" uuid NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "comments" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"project_id" uuid NOT NULL,
	"pull_request_id" uuid,
	"shape_id" uuid,
	"parent_id" uuid,
	"author_id" uuid NOT NULL,
	"content" text NOT NULL,
	"x" double precision,
	"y" double precision,
	"resolved" boolean DEFAULT false NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "commits" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"project_id" uuid NOT NULL,
	"branch_id" uuid NOT NULL,
	"parent_id" uuid,
	"message" text NOT NULL,
	"author_id" uuid NOT NULL,
	"snapshot_id" uuid NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "frames" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"project_id" uuid NOT NULL,
	"name" text NOT NULL,
	"x" double precision DEFAULT 0 NOT NULL,
	"y" double precision DEFAULT 0 NOT NULL,
	"width" double precision DEFAULT 800 NOT NULL,
	"height" double precision DEFAULT 600 NOT NULL,
	"background_color" varchar(9),
	"clip_content" boolean DEFAULT true NOT NULL,
	"sort_order" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "projects" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"description" text,
	"owner_id" uuid NOT NULL,
	"team_id" uuid,
	"is_public" boolean DEFAULT false NOT NULL,
	"default_branch_id" uuid,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL,
	"deleted_at" timestamp
);
--> statement-breakpoint
CREATE TABLE "pull_requests" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"project_id" uuid NOT NULL,
	"source_branch_id" uuid NOT NULL,
	"target_branch_id" uuid NOT NULL,
	"title" text NOT NULL,
	"description" text,
	"status" varchar(20) DEFAULT 'open' NOT NULL,
	"author_id" uuid NOT NULL,
	"reviewers" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL,
	"merged_at" timestamp,
	"closed_at" timestamp
);
--> statement-breakpoint
CREATE TABLE "shapes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"project_id" uuid NOT NULL,
	"frame_id" uuid,
	"parent_id" uuid,
	"type" varchar(50) NOT NULL,
	"name" text NOT NULL,
	"transform_a" double precision DEFAULT 1 NOT NULL,
	"transform_b" double precision DEFAULT 0 NOT NULL,
	"transform_c" double precision DEFAULT 0 NOT NULL,
	"transform_d" double precision DEFAULT 1 NOT NULL,
	"transform_e" double precision DEFAULT 0 NOT NULL,
	"transform_f" double precision DEFAULT 0 NOT NULL,
	"x" double precision NOT NULL,
	"y" double precision NOT NULL,
	"width" double precision NOT NULL,
	"height" double precision NOT NULL,
	"rotation" double precision DEFAULT 0 NOT NULL,
	"fills" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"strokes" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"opacity" double precision DEFAULT 1 NOT NULL,
	"properties" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"hidden" boolean DEFAULT false NOT NULL,
	"blocked" boolean DEFAULT false NOT NULL,
	"sort_order" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "snapshots" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"project_id" uuid NOT NULL,
	"data" jsonb NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "branches" ADD CONSTRAINT "branches_project_id_projects_id_fk" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "comments" ADD CONSTRAINT "comments_project_id_projects_id_fk" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "comments" ADD CONSTRAINT "comments_pull_request_id_pull_requests_id_fk" FOREIGN KEY ("pull_request_id") REFERENCES "public"."pull_requests"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "comments" ADD CONSTRAINT "comments_shape_id_shapes_id_fk" FOREIGN KEY ("shape_id") REFERENCES "public"."shapes"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "commits" ADD CONSTRAINT "commits_project_id_projects_id_fk" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "commits" ADD CONSTRAINT "commits_branch_id_branches_id_fk" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "frames" ADD CONSTRAINT "frames_project_id_projects_id_fk" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "pull_requests" ADD CONSTRAINT "pull_requests_project_id_projects_id_fk" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "pull_requests" ADD CONSTRAINT "pull_requests_source_branch_id_branches_id_fk" FOREIGN KEY ("source_branch_id") REFERENCES "public"."branches"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "pull_requests" ADD CONSTRAINT "pull_requests_target_branch_id_branches_id_fk" FOREIGN KEY ("target_branch_id") REFERENCES "public"."branches"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "shapes" ADD CONSTRAINT "shapes_project_id_projects_id_fk" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "snapshots" ADD CONSTRAINT "snapshots_project_id_projects_id_fk" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "branches_project_idx" ON "branches" USING btree ("project_id");--> statement-breakpoint
CREATE INDEX "branches_name_idx" ON "branches" USING btree ("project_id","name");--> statement-breakpoint
CREATE INDEX "comments_project_idx" ON "comments" USING btree ("project_id");--> statement-breakpoint
CREATE INDEX "comments_shape_idx" ON "comments" USING btree ("shape_id");--> statement-breakpoint
CREATE INDEX "comments_pr_idx" ON "comments" USING btree ("pull_request_id");--> statement-breakpoint
CREATE INDEX "commits_project_idx" ON "commits" USING btree ("project_id");--> statement-breakpoint
CREATE INDEX "commits_branch_idx" ON "commits" USING btree ("branch_id");--> statement-breakpoint
CREATE INDEX "commits_parent_idx" ON "commits" USING btree ("parent_id");--> statement-breakpoint
CREATE INDEX "frames_project_idx" ON "frames" USING btree ("project_id");--> statement-breakpoint
CREATE INDEX "projects_owner_idx" ON "projects" USING btree ("owner_id");--> statement-breakpoint
CREATE INDEX "projects_team_idx" ON "projects" USING btree ("team_id");--> statement-breakpoint
CREATE INDEX "prs_project_idx" ON "pull_requests" USING btree ("project_id");--> statement-breakpoint
CREATE INDEX "prs_status_idx" ON "pull_requests" USING btree ("status");--> statement-breakpoint
CREATE INDEX "shapes_project_idx" ON "shapes" USING btree ("project_id");--> statement-breakpoint
CREATE INDEX "shapes_frame_idx" ON "shapes" USING btree ("frame_id");--> statement-breakpoint
CREATE INDEX "shapes_parent_idx" ON "shapes" USING btree ("parent_id");--> statement-breakpoint
CREATE INDEX "shapes_type_idx" ON "shapes" USING btree ("type");