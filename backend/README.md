# Vio Backend

Bun + Elysia backend with Git-like version control for design projects.

## Prerequisites

- [Bun](https://bun.sh/) (v1.1+)
- [Docker](https://www.docker.com/) (for PostgreSQL)

## Quick Start

1. **Start PostgreSQL**
   ```bash
   docker-compose up -d postgres
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
   bun run dev
   ```

6. **Open Swagger docs**
   ```
   http://localhost:4000/swagger
   ```

## Available Scripts

| Command | Description |
|---------|-------------|
| `bun run dev` | Start development server with hot reload |
| `bun run start` | Start production server |
| `bun run build` | Build for production |
| `bun run db:generate` | Generate Drizzle migrations |
| `bun run db:migrate` | Run migrations |
| `bun run db:push` | Push schema to database |
| `bun run db:studio` | Open Drizzle Studio |
| `bun run test` | Run tests |
| `bun run lint` | Lint code |
| `bun run format` | Format code |

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
