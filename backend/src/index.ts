/**
 * Vio Backend - ConnectRPC Server
 *
 * Uses ConnectRPC with Node.js HTTP/2 for browser and native client support.
 * Supports Connect protocol (HTTP/1.1 + JSON) and gRPC-Web for Flutter web.
 */

import type { ConnectRouter } from "@connectrpc/connect";
import { connectNodeAdapter } from "@connectrpc/connect-node";
import { readFileSync } from "node:fs";
import {
	createSecureServer as createHttp2SecureServer,
	createServer as createHttp2Server,
} from "node:http2";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { AssetService } from "./gen/vio/v1/asset_pb.js";
import { AuthService } from "./gen/vio/v1/auth_pb.js";
import { BranchService } from "./gen/vio/v1/branch_pb.js";
import { CanvasService } from "./gen/vio/v1/canvas_pb.js";
import { CommitService } from "./gen/vio/v1/commit_pb.js";
import { ProjectService } from "./gen/vio/v1/project_pb.js";
import { PullRequestService } from "./gen/vio/v1/pullrequest_pb.js";
import { ShapeService } from "./gen/vio/v1/shape_pb.js";

import { authInterceptor, loggingInterceptor } from "./interceptors/index.js";
import {
	assetServiceImpl,
	authServiceImpl,
	branchServiceImpl,
	canvasServiceImpl,
	commitServiceImpl,
	ensureAdminUser,
	projectServiceImpl,
	pullRequestServiceImpl,
	shapeServiceImpl,
} from "./services/index.js";
import { getPerfDiagnosticsConfig } from "./utils/perf-diagnostics.js";

// ============================================================================
// Server Setup
// ============================================================================

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const PORT = Number(process.env.PORT) || 4000;
const WEB_PORT = Number(process.env.WEB_PORT) || 4001;
const USE_TLS = process.env.USE_TLS === "true";
const perfDiagnostics = getPerfDiagnosticsConfig();

// Create ConnectRPC router with all services
function createRoutes(router: ConnectRouter) {
	router.service(AssetService, assetServiceImpl);
	router.service(AuthService, authServiceImpl);
	router.service(ProjectService, projectServiceImpl);
	router.service(BranchService, branchServiceImpl);
	router.service(CommitService, commitServiceImpl);
	router.service(ShapeService, shapeServiceImpl);
	router.service(CanvasService, canvasServiceImpl);
	router.service(PullRequestService, pullRequestServiceImpl);
}

// CORS configuration for browser clients
// In development, Flutter web uses random ports, so we allow any localhost origin
function isAllowedOrigin(origin: string | undefined): boolean {
	if (!origin) return true; // Allow requests without origin (curl, Postman)

	// Allow any localhost or 127.0.0.1 origin (any port)
	if (
		origin.startsWith("http://localhost:") ||
		origin.startsWith("http://127.0.0.1:") ||
		origin.startsWith("https://localhost:") ||
		origin.startsWith("https://127.0.0.1:")
	) {
		return true;
	}

	return false;
}

// ConnectRPC required headers for CORS
const CONNECT_HEADERS = [
	"Content-Type",
	"Connect-Protocol-Version",
	"Connect-Timeout-Ms",
	"X-Grpc-Web",
	"X-User-Agent",
];

function setCorsHeaders(
	req: { headers: { origin?: string } },
	res: { setHeader: (name: string, value: string) => void },
) {
	const origin = req.headers.origin;
	if (isAllowedOrigin(origin)) {
		// Echo back the requesting origin (required for credentials)
		res.setHeader("Access-Control-Allow-Origin", origin || "*");
	}
	res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
	res.setHeader(
		"Access-Control-Allow-Headers",
		[...CONNECT_HEADERS, "Authorization"].join(", "),
	);
	res.setHeader(
		"Access-Control-Expose-Headers",
		"Grpc-Status, Grpc-Message, Grpc-Status-Details-Bin",
	);
	res.setHeader("Access-Control-Max-Age", "86400"); // 24 hours
}

// Create the ConnectRPC handler
const connectHandler = connectNodeAdapter({
	routes: createRoutes,
	connect: true,
	grpcWeb: true, // Enable gRPC-Web for Flutter web client
	interceptors: [authInterceptor, loggingInterceptor],
});

// Wrap handler with CORS support
const handler = (
	req: Parameters<typeof connectHandler>[0],
	res: Parameters<typeof connectHandler>[1],
) => {
	setCorsHeaders(req, res);

	// Handle preflight OPTIONS requests
	if (req.method === "OPTIONS") {
		res.writeHead(204);
		res.end();
		return;
	}

	return connectHandler(req, res);
};

// Bootstrap admin user on startup
await ensureAdminUser();

// Create and start server
// For development: Use HTTP/1.1 for easy testing with curl/Postman
// For production with TLS: Use HTTP/2 for better performance

if (USE_TLS) {
	// HTTPS/HTTP2 with TLS (for gRPC protocol support)
	const certPath = join(__dirname, "..", "localhost+2.pem");
	const keyPath = join(__dirname, "..", "localhost+2-key.pem");

	try {
		const server = createHttp2SecureServer(
			{
				cert: readFileSync(certPath),
				key: readFileSync(keyPath),
				allowHTTP1: true, // Allow HTTP/1.1 for Connect protocol
			},
			handler,
		);
		server.listen(PORT, "0.0.0.0", () => {
			console.log(`
🎨 Vio Backend is running

   URL: https://0.0.0.0:${PORT}
   Protocol: ConnectRPC (HTTP/1.1 + HTTP/2 with TLS)

   Services:
   - vio.v1.AssetService
   - vio.v1.AuthService
   - vio.v1.ProjectService
   - vio.v1.BranchService
   - vio.v1.CommitService
   - vio.v1.ShapeService
   - vio.v1.CanvasService
   - vio.v1.PullRequestService

   Supported Protocols:
   - Connect (HTTP/1.1 + JSON) ✓
   - gRPC-Web ✓
   - gRPC (with TLS) ✓

   Press Ctrl+C to stop
`);
		});
	} catch (e) {
		console.error("Could not load TLS certificates:", e);
		process.exit(1);
	}
} else {
	// Development mode: Run two servers
	// - HTTP/2 on PORT (4000) for native gRPC from Desktop/Mobile
	// - HTTP/1.1 on WEB_PORT (4001) for gRPC-Web from browsers

	const { createServer: createHttp1Server } = await import("node:http");

	// HTTP/2 server for native gRPC (Desktop/Mobile)
	const http2Server = createHttp2Server(handler);
	http2Server.listen(PORT, "0.0.0.0", () => {
		console.log(
			`   ✓ HTTP/2 server on port ${PORT} (Desktop/Mobile - native gRPC)`,
		);
	});

	// HTTP/1.1 server for gRPC-Web (browsers)
	const http1Server = createHttp1Server(handler);
	http1Server.listen(WEB_PORT, "0.0.0.0", () => {
		console.log(`   ✓ HTTP/1.1 server on port ${WEB_PORT} (Web - gRPC-Web)`);
	});

	if (perfDiagnostics.enabled) {
		console.log(
			`   ✓ Performance diagnostics enabled: ${perfDiagnostics.filePath}`,
		);
	}

	console.log(`
🎨 Vio Backend is running

   Desktop/Mobile: http://localhost:${PORT} (HTTP/2 native gRPC)
   Web Browser:    http://localhost:${WEB_PORT} (HTTP/1.1 gRPC-Web)

   Services:
   - vio.v1.AssetService
   - vio.v1.AuthService
   - vio.v1.ProjectService
   - vio.v1.BranchService
   - vio.v1.CommitService
   - vio.v1.ShapeService
   - vio.v1.CanvasService
   - vio.v1.PullRequestService

   Press Ctrl+C to stop
`);
}
