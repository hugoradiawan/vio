/**
 * ConnectRPC Auth Interceptor
 *
 * Validates access tokens on all RPC calls except public auth endpoints.
 * Attaches authenticated user info to request headers for downstream services.
 */

import { Code, ConnectError, type Interceptor } from "@connectrpc/connect";
import { validateAccessToken } from "../services/auth.js";

/** RPC methods that don't require authentication */
const DEFAULT_PUBLIC_METHODS = ["Register", "Login", "RefreshToken", "ValidateToken"] as const;

const PUBLIC_METHODS = new Set<string>(
	(process.env.VIO_PUBLIC_RPC_METHODS
		?.split(",")
		.map((name) => name.trim())
		.filter((name) => name.length > 0)) ??
		[...DEFAULT_PUBLIC_METHODS],
);
/**
 * Auth interceptor that validates Bearer tokens.
 *
 * Reads the `authorization` header, validates the token, and throws
 * UNAUTHENTICATED if the token is missing or invalid on protected routes.
 */
export const authInterceptor: Interceptor = (next) => async (req) => {
	// Extract method name from the URL path (e.g., "/vio.v1.AuthService/Login" → "Login")
	const procedureName = req.method.name;

	// Skip auth for public endpoints
	if (PUBLIC_METHODS.has(procedureName)) {
		return next(req);
	}

	// Get authorization header
	const authHeader = req.header.get("authorization") ?? undefined;

	const user = await validateAccessToken(authHeader);
	if (!user) {
		throw new ConnectError(
			"Authentication required. Please provide a valid access token.",
			Code.Unauthenticated,
		);
	}

	// Attach user info to request headers for downstream services
	req.header.set("x-user-id", user.id);
	req.header.set("x-user-email", user.email);
	req.header.set("x-user-name", user.name);

	return next(req);
};
