import type { ConnectRouter } from "@connectrpc/connect";
import { Code, ConnectError } from "@connectrpc/connect";
import { nanoid } from "nanoid";
import { AuthService } from "../gen/vio/v1/auth_connect.js";
import {
    AuthResponse,
    User,
    ValidateTokenResponse,
} from "../gen/vio/v1/auth_pb.js";
import { Timestamp as ProtoTimestamp } from "../gen/vio/v1/common_pb.js";

// ============================================================================
// In-Memory User Store (replace with database in production)
// ============================================================================

interface StoredUser {
	id: string;
	email: string;
	name: string;
	passwordHash: string;
	avatarUrl?: string;
	createdAt: Date;
}

interface StoredToken {
	userId: string;
	expiresAt: number;
}

const users = new Map<string, StoredUser>();
const usersByEmail = new Map<string, string>(); // email -> userId
const accessTokens = new Map<string, StoredToken>();
const refreshTokens = new Map<string, StoredToken>();

// Token validity durations
const ACCESS_TOKEN_DURATION = 15 * 60 * 1000; // 15 minutes
const REFRESH_TOKEN_DURATION = 7 * 24 * 60 * 60 * 1000; // 7 days

// ============================================================================
// Helper Functions
// ============================================================================

function toProtoTimestamp(date: Date): ProtoTimestamp {
	return new ProtoTimestamp({
		millis: BigInt(date.getTime()),
	});
}

function toProtoUser(stored: StoredUser): User {
	return new User({
		id: stored.id,
		email: stored.email,
		name: stored.name,
		avatarUrl: stored.avatarUrl,
		createdAt: toProtoTimestamp(stored.createdAt),
	});
}

// Simple hash function (use bcrypt in production!)
async function hashPassword(password: string): Promise<string> {
	const encoder = new TextEncoder();
	const data = encoder.encode(password);
	const hashBuffer = await crypto.subtle.digest("SHA-256", data);
	const hashArray = Array.from(new Uint8Array(hashBuffer));
	return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function verifyPassword(
	password: string,
	hash: string,
): Promise<boolean> {
	const inputHash = await hashPassword(password);
	return inputHash === hash;
}

function generateAccessToken(userId: string): string {
	const token = `vio_at_${nanoid(32)}`;
	accessTokens.set(token, {
		userId,
		expiresAt: Date.now() + ACCESS_TOKEN_DURATION,
	});
	return token;
}

function generateRefreshToken(userId: string): string {
	const token = `vio_rt_${nanoid(48)}`;
	refreshTokens.set(token, {
		userId,
		expiresAt: Date.now() + REFRESH_TOKEN_DURATION,
	});
	return token;
}

// ============================================================================
// Service Registration
// ============================================================================

export function registerAuthService(router: ConnectRouter) {
	router.service(AuthService, {
		async register(req) {
			// Validate input
			if (!req.email || !req.password || !req.name) {
				throw new ConnectError(
					"Email, password, and name are required",
					Code.InvalidArgument,
				);
			}

			if (req.password.length < 8) {
				throw new ConnectError(
					"Password must be at least 8 characters",
					Code.InvalidArgument,
				);
			}

			// Check if email is already taken
			if (usersByEmail.has(req.email.toLowerCase())) {
				throw new ConnectError("Email already registered", Code.AlreadyExists);
			}

			// Create user
			const userId = nanoid(21);
			const passwordHash = await hashPassword(req.password);
			const now = new Date();

			const user: StoredUser = {
				id: userId,
				email: req.email.toLowerCase(),
				name: req.name,
				passwordHash,
				createdAt: now,
			};

			users.set(userId, user);
			usersByEmail.set(user.email, userId);

			// Generate tokens
			const accessToken = generateAccessToken(userId);
			const refreshToken = generateRefreshToken(userId);

			console.log(`User registered: ${user.email} (${userId})`);

			return new AuthResponse({
				user: toProtoUser(user),
				accessToken,
				refreshToken,
				expiresIn: BigInt(Math.floor(ACCESS_TOKEN_DURATION / 1000)),
			});
		},

		async login(req) {
			// Validate input
			if (!req.email || !req.password) {
				throw new ConnectError(
					"Email and password are required",
					Code.InvalidArgument,
				);
			}

			// Find user
			const userId = usersByEmail.get(req.email.toLowerCase());
			if (!userId) {
				throw new ConnectError(
					"Invalid email or password",
					Code.Unauthenticated,
				);
			}

			const user = users.get(userId);
			if (!user) {
				throw new ConnectError(
					"Invalid email or password",
					Code.Unauthenticated,
				);
			}

			// Verify password
			const valid = await verifyPassword(req.password, user.passwordHash);
			if (!valid) {
				throw new ConnectError(
					"Invalid email or password",
					Code.Unauthenticated,
				);
			}

			// Generate tokens
			const accessToken = generateAccessToken(userId);
			const refreshToken = generateRefreshToken(userId);

			console.log(`User logged in: ${user.email}`);

			return new AuthResponse({
				user: toProtoUser(user),
				accessToken,
				refreshToken,
				expiresIn: BigInt(Math.floor(ACCESS_TOKEN_DURATION / 1000)),
			});
		},

		async refreshToken(req) {
			// Validate input
			if (!req.refreshToken) {
				throw new ConnectError(
					"Refresh token is required",
					Code.InvalidArgument,
				);
			}

			// Verify refresh token
			const tokenData = refreshTokens.get(req.refreshToken);
			if (!tokenData) {
				throw new ConnectError("Invalid refresh token", Code.Unauthenticated);
			}

			if (Date.now() > tokenData.expiresAt) {
				refreshTokens.delete(req.refreshToken);
				throw new ConnectError("Refresh token expired", Code.Unauthenticated);
			}

			const user = users.get(tokenData.userId);
			if (!user) {
				throw new ConnectError("User not found", Code.NotFound);
			}

			// Revoke old refresh token
			refreshTokens.delete(req.refreshToken);

			// Generate new tokens
			const accessToken = generateAccessToken(user.id);
			const refreshToken = generateRefreshToken(user.id);

			return new AuthResponse({
				accessToken,
				refreshToken,
				expiresIn: BigInt(Math.floor(ACCESS_TOKEN_DURATION / 1000)),
			});
		},

		async validateToken(req) {
			// Validate input
			if (!req.accessToken) {
				throw new ConnectError(
					"Access token is required",
					Code.InvalidArgument,
				);
			}

			// Verify access token
			const tokenData = accessTokens.get(req.accessToken);
			if (!tokenData) {
				return new ValidateTokenResponse({ valid: false });
			}

			if (Date.now() > tokenData.expiresAt) {
				accessTokens.delete(req.accessToken);
				return new ValidateTokenResponse({ valid: false });
			}

			const user = users.get(tokenData.userId);
			if (!user) {
				return new ValidateTokenResponse({ valid: false });
			}

			return new ValidateTokenResponse({
				valid: true,
				user: toProtoUser(user),
			});
		},

		async logout(req) {
			// Revoke tokens
			if (req.refreshToken) {
				refreshTokens.delete(req.refreshToken);
			}

			// Note: In the proto, LogoutRequest only has refreshToken field
			// Access token invalidation would need to be handled by the auth header
			return {};
		},
	});
}

// ============================================================================
// Token Validation Middleware Helper
// ============================================================================

export function validateAccessToken(
	token: string | undefined,
): StoredUser | null {
	if (!token) return null;

	// Remove "Bearer " prefix if present
	const cleanToken = token.startsWith("Bearer ") ? token.slice(7) : token;

	const tokenData = accessTokens.get(cleanToken);
	if (!tokenData) return null;

	if (Date.now() > tokenData.expiresAt) {
		accessTokens.delete(cleanToken);
		return null;
	}

	const user = users.get(tokenData.userId);
	return user ?? null;
}
