import { createConnectRouter, type ConnectRouter } from "@connectrpc/connect";
import {
	universalServerRequestFromFetch,
	universalServerResponseToFetch,
} from "@connectrpc/connect/protocol";
import {
	registerAuthService,
	registerBranchService,
	registerCanvasService,
	registerCommitService,
	registerProjectService,
	registerShapeService,
} from "./services/index.js";

// ============================================================================
// Create Connect Router with All Services
// ============================================================================

function routes(router: ConnectRouter) {
	registerAuthService(router);
	registerProjectService(router);
	registerBranchService(router);
	registerCommitService(router);
	registerShapeService(router);
	registerCanvasService(router);
}

// Create the router with all services
const router = createConnectRouter();
routes(router);

// ============================================================================
// CORS Headers
// ============================================================================

const corsHeaders = {
	"Access-Control-Allow-Origin": "*",
	"Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, PATCH, OPTIONS",
	"Access-Control-Allow-Headers":
		"Content-Type, Authorization, Connect-Protocol-Version, Connect-Timeout-Ms, X-User-Agent",
	"Access-Control-Expose-Headers": "Connect-Protocol-Version",
	"Access-Control-Max-Age": "86400",
};

// ============================================================================
// Bun Server with Connect Handler (using universal handler)
// ============================================================================

const PORT = Number(process.env.PORT) || 4000;

const server = Bun.serve({
	port: PORT,
	async fetch(req) {
		const url = new URL(req.url);

		// Handle CORS preflight
		if (req.method === "OPTIONS") {
			return new Response(null, {
				status: 204,
				headers: corsHeaders,
			});
		}

		// Health check endpoint
		if (url.pathname === "/health") {
			return Response.json(
				{ status: "healthy", timestamp: new Date().toISOString() },
				{ headers: corsHeaders },
			);
		}

		// Root endpoint
		if (url.pathname === "/") {
			return Response.json(
				{
					name: "Vio API",
					version: "0.2.0",
					status: "running",
					protocol: "Connect/gRPC",
					services: [
						"vio.v1.AuthService",
						"vio.v1.ProjectService",
						"vio.v1.BranchService",
						"vio.v1.CommitService",
						"vio.v1.ShapeService",
						"vio.v1.CanvasService",
					],
				},
				{ headers: corsHeaders },
			);
		}

		// Connect/gRPC requests - find matching handler
		try {
			// Find the handler that matches this request path
			const handler = router.handlers.find(
				(h) => url.pathname === h.requestPath && h.allowedMethods.includes(req.method)
			);

			if (!handler) {
				return Response.json(
					{ error: "Not found" },
					{ status: 404, headers: corsHeaders },
				);
			}

			const uReq = universalServerRequestFromFetch(req, {});
			const uRes = await handler(uReq);
			const response = universalServerResponseToFetch(uRes);

			// Add CORS headers to response
			const newHeaders = new Headers(response.headers);
			for (const [key, value] of Object.entries(corsHeaders)) {
				newHeaders.set(key, value);
			}

			return new Response(response.body, {
				status: response.status,
				statusText: response.statusText,
				headers: newHeaders,
			});
		} catch (error) {
			console.error("Request error:", error);
			return Response.json(
				{ error: "Internal server error" },
				{ status: 500, headers: corsHeaders },
			);
		}
	},
});

console.log(`
🎨 Vio Backend is running

   URL: http://localhost:${PORT}
   Protocol: Connect/gRPC-Web

   Services:
   - vio.v1.AuthService
   - vio.v1.ProjectService
   - vio.v1.BranchService
   - vio.v1.CommitService
   - vio.v1.ShapeService
   - vio.v1.CanvasService (with streaming)

   Press Ctrl+C to stop
`);
