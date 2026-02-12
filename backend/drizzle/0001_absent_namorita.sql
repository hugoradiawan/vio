CREATE TABLE "project_assets" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"project_id" uuid NOT NULL,
	"name" text NOT NULL,
	"path" text,
	"mime_type" varchar(100) NOT NULL,
	"width" integer DEFAULT 0 NOT NULL,
	"height" integer DEFAULT 0 NOT NULL,
	"data" "bytea" NOT NULL,
	"thumbnail" "bytea",
	"file_size" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "project_colors" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"project_id" uuid NOT NULL,
	"name" text NOT NULL,
	"path" text,
	"color" varchar(9),
	"opacity" real DEFAULT 1 NOT NULL,
	"gradient" jsonb,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "project_assets" ADD CONSTRAINT "project_assets_project_id_projects_id_fk" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "project_colors" ADD CONSTRAINT "project_colors_project_id_projects_id_fk" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "project_assets_project_idx" ON "project_assets" USING btree ("project_id");--> statement-breakpoint
CREATE INDEX "project_assets_path_idx" ON "project_assets" USING btree ("project_id","path");--> statement-breakpoint
CREATE INDEX "project_colors_project_idx" ON "project_colors" USING btree ("project_id");--> statement-breakpoint
CREATE INDEX "project_colors_path_idx" ON "project_colors" USING btree ("project_id","path");