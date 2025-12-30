import { cors } from '@elysiajs/cors';
import { swagger } from '@elysiajs/swagger';
import { Elysia } from 'elysia';
import { branchRoutes } from './routes/branches';
import { commitRoutes } from './routes/commits';
import { projectRoutes } from './routes/projects';
import { shapeRoutes } from './routes/shapes';

const app = new Elysia()
  .use(
    cors({
      origin: process.env.CORS_ORIGIN || 'http://localhost:3000',
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
      allowedHeaders: ['Content-Type', 'Authorization'],
    }),
  )
  .use(
    swagger({
      documentation: {
        info: {
          title: 'Vio API',
          version: '0.1.0',
          description: 'Design Tool with Git-like Version Control',
        },
        tags: [
          { name: 'Projects', description: 'Project management' },
          { name: 'Branches', description: 'Branch management (Git-like)' },
          { name: 'Commits', description: 'Commit history' },
          { name: 'Shapes', description: 'Shape operations' },
        ],
      },
    }),
  )
  .get('/', () => ({
    name: 'Vio API',
    version: '0.1.0',
    status: 'running',
  }))
  .get('/health', () => ({
    status: 'healthy',
    timestamp: new Date().toISOString(),
  }))
  .use(projectRoutes)
  .use(branchRoutes)
  .use(commitRoutes)
  .use(shapeRoutes)
  .listen(process.env.PORT || 4000);

console.log(`
🎨 Vio Backend is running

   URL: http://${app.server?.hostname}:${app.server?.port}
   Swagger: http://${app.server?.hostname}:${app.server?.port}/swagger

   Press Ctrl+C to stop
`);

export type App = typeof app;
