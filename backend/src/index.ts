/**
 * Vio Backend - Native gRPC Server
 *
 * Uses nice-grpc with @grpc/grpc-js for native gRPC wire protocol.
 * Server reflection is enabled for tools like Postman, grpcurl, etc.
 */

import { createServer } from "nice-grpc";
import { ServerReflection, ServerReflectionService } from "nice-grpc-server-reflection";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { AuthServiceDefinition } from "./gen/vio/v1/auth.js";
import { BranchServiceDefinition } from "./gen/vio/v1/branch.js";
import { CanvasServiceDefinition } from "./gen/vio/v1/canvas.js";
import { CommitServiceDefinition } from "./gen/vio/v1/commit.js";
import { ProjectServiceDefinition } from "./gen/vio/v1/project.js";
import { ShapeServiceDefinition } from "./gen/vio/v1/shape.js";

import {
	authServiceImpl,
	branchServiceImpl,
	canvasServiceImpl,
	commitServiceImpl,
	projectServiceImpl,
	shapeServiceImpl,
} from "./services/index.js";

// ============================================================================
// Server Setup
// ============================================================================

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const PORT = Number(process.env.PORT) || 4000;

// Load proto descriptor for reflection
const descriptorPath = join(__dirname, "vio.binpb");
let protoDescriptor: Buffer;
try {
	protoDescriptor = readFileSync(descriptorPath);
} catch (e) {
	console.error("Could not load proto descriptor:", e);
	process.exit(1);
}

// Create gRPC server
const server = createServer();

// Register all services
server.add(AuthServiceDefinition, authServiceImpl);
server.add(ProjectServiceDefinition, projectServiceImpl);
server.add(BranchServiceDefinition, branchServiceImpl);
server.add(CommitServiceDefinition, commitServiceImpl);
server.add(ShapeServiceDefinition, shapeServiceImpl);
server.add(CanvasServiceDefinition, canvasServiceImpl);

// Add server reflection for Postman/grpcurl discovery
server.add(
	ServerReflectionService,
	ServerReflection(protoDescriptor, [
		"vio.v1.AuthService",
		"vio.v1.ProjectService",
		"vio.v1.BranchService",
		"vio.v1.CommitService",
		"vio.v1.ShapeService",
		"vio.v1.CanvasService",
	]),
);

// Start server
await server.listen(`0.0.0.0:${PORT}`);

console.log(`
🎨 Vio Backend is running

   URL: 0.0.0.0:${PORT}
   Protocol: Native gRPC (HTTP/2)

   Services:
   - vio.v1.AuthService
   - vio.v1.ProjectService
   - vio.v1.BranchService
   - vio.v1.CommitService
   - vio.v1.ShapeService
   - vio.v1.CanvasService

   Server Reflection: Enabled ✓
   (Use Postman, grpcurl, or any gRPC client with reflection)

   Press Ctrl+C to stop
`);
