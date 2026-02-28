# Vio Backend

Bun + Elysia backend with Git-like version control for design projects.

## Prerequisites

- [Bun](https://bun.sh/) (v1.1+)
- [Docker](https://www.docker.com/) (for PostgreSQL)

## Quick Start

1. **Start PostgreSQL**
   ```bash
   podman compose up -d postgres
   ```

2. **Install dependencies**
   ```bash
   bun install
   ```

3. **Set up environment**
   ```bash
   cp .env.example .env
   ```

4. **Run database migrations**
   ```bash
   bun run db:push
   ```

5. **Start development server**
   ```bash
   bun run dev:ready
   ```

6. **Open Swagger docs**
   ```
   http://localhost:4000/swagger
   ```

## Available Scripts

| Command | Description |
|---------|-------------|
| `bun run dev` | Start development server with hot reload |
| `bun run dev:preflight` | Ensure Podman/Postgres/DB readiness for local dev |
| `bun run dev:ready` | Run preflight, then start development server |
| `bun run dev:diagnostics` | Start server with performance diagnostics JSONL logging |
| `bun run dev:diagnostics:ready` | Run preflight, then diagnostics server |
| `bun run start` | Start production server |
| `bun run build` | Build for production |
| `bun run db:generate` | Generate Drizzle migrations |
| `bun run db:migrate` | Run migrations |
| `bun run db:push` | Push schema to database |
| `bun run db:studio` | Open Drizzle Studio |
| `bun run db:seed` | Seed default demo project |
| `bun run db:seed:stress:small` | Seed stress dataset (small) |
| `bun run db:seed:stress:medium` | Seed stress dataset (medium) |
| `bun run db:seed:stress:large` | Seed stress dataset (large) |
| `bun run test` | Run tests |
| `bun run lint` | Lint code |
| `bun run format` | Format code |

## Stress Seed Datasets

Stress seed scripts create separate projects and use image binaries from the repository-level `images/` folder.

- `small`: ~12 frames, ~2.1k shape rows, 30 assets, 2 branches, 24 commits
- `medium`: ~36 frames, ~8.6k shape rows, 100 assets, 3 branches, 54 commits
- `large`: ~96 frames, ~28.9k shape rows, 300 assets, 5 branches, 120 commits

Recommended flow:

```bash
bun run db:push
bun run db:seed:stress:small
```

## Performance Diagnostics Logs

To capture backend performance diagnostics while you interact with the app:

```bash
bun run dev:diagnostics
```

This writes JSON Lines logs to:

- `backend/logs/perf-diagnostics.jsonl` (default)

You can customize the output path:

```bash
PERF_DIAGNOSTICS=1 PERF_DIAGNOSTICS_FILE=./logs/my-run.jsonl bun run dev
```

Each log line contains operation name, duration in ms, request context, and any error metadata.

## API Endpoints

### Projects
- `GET /api/projects` - List projects
- `GET /api/projects/:id` - Get project
- `POST /api/projects` - Create project
- `PATCH /api/projects/:id` - Update project
- `DELETE /api/projects/:id` - Delete project

### Branches (Git-like)
- `GET /api/projects/:id/branches` - List branches
- `POST /api/projects/:id/branches` - Create branch
- `DELETE /api/projects/:id/branches/:branchId` - Delete branch

### Commits
- `GET /api/projects/:id/commits` - List commits
- `POST /api/projects/:id/commits` - Create commit
- `GET /api/projects/:id/commits/:commitId/diff/:targetId` - Get diff

### Shapes
- `GET /api/projects/:id/shapes` - List shapes
- `POST /api/projects/:id/shapes` - Create shape
- `PATCH /api/projects/:id/shapes/:shapeId` - Update shape
- `DELETE /api/projects/:id/shapes/:shapeId` - Delete shape
- `POST /api/projects/:id/shapes/batch` - Batch operations

## Database Schema

```
projects
├── branches (Git-like branching)
│   └── commits (Snapshots)
├── frames (Artboards)
│   └── shapes (All shape types)
├── pull_requests (Design review)
└── comments (Feedback)
```

## Architecture

- **Framework**: Elysia (fast Bun web framework)
- **Database**: PostgreSQL with Drizzle ORM
- **Validation**: Zod schemas via Elysia
- **API Docs**: Swagger/OpenAPI
