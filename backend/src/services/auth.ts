/**
 * Auth service implementation for nice-grpc.
 */

import { nanoid } from "nanoid";
import { ServerError, Status } from "nice-grpc";
import type {
	AuthResponse,
	AuthServiceImplementation,
	User,
	ValidateTokenResponse,
} from "../gen/vio/v1/auth.js";
import type { Empty, Timestamp } from "../gen/vio/v1/common.js";

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

function toProtoTimestamp(date: Date): Timestamp {
	return {
		millis: BigInt(date.getTime()),
	};
}

function toProtoUser(stored: StoredUser): User {
	return {
		id: stored.id,
		email: stored.email,
		name: stored.name,
		avatarUrl: stored.avatarUrl,
		createdAt: toProtoTimestamp(stored.createdAt),
	};
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
// Service Implementation
// ============================================================================

export const authServiceImpl: AuthServiceImplementation = {
	async register(req): Promise<AuthResponse> {
		// Validate input
		if (!req.email || !req.password || !req.name) {
			throw new ServerError(
				Status.INVALID_ARGUMENT,
				"Email, password, and name are required",
			);
		}

		if (req.password.length < 8) {
			throw new ServerError(
				Status.INVALID_ARGUMENT,
				"Password must be at least 8 characters",
			);
		}

		// Check if email is already taken
		if (usersByEmail.has(req.email.toLowerCase())) {
			throw new ServerError(Status.ALREADY_EXISTS, "Email already registered");
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

		return {
			user: toProtoUser(user),
			accessToken,
			refreshToken,
			expiresIn: BigInt(Math.floor(ACCESS_TOKEN_DURATION / 1000)),
		};
	},

	async login(req): Promise<AuthResponse> {
		// Validate input
		if (!req.email || !req.password) {
			throw new ServerError(
				Status.INVALID_ARGUMENT,
				"Email and password are required",
			);
		}

		// Find user
		const userId = usersByEmail.get(req.email.toLowerCase());
		if (!userId) {
			throw new ServerError(Status.UNAUTHENTICATED, "Invalid email or password");
		}

		const user = users.get(userId);
		if (!user) {
			throw new ServerError(Status.UNAUTHENTICATED, "Invalid email or password");
		}

		// Verify password
		const valid = await verifyPassword(req.password, user.passwordHash);
		if (!valid) {
			throw new ServerError(Status.UNAUTHENTICATED, "Invalid email or password");
		}

		// Generate tokens
		const accessToken = generateAccessToken(userId);
		const refreshToken = generateRefreshToken(userId);

		console.log(`User logged in: ${user.email}`);

		return {
			user: toProtoUser(user),
			accessToken,
			refreshToken,
			expiresIn: BigInt(Math.floor(ACCESS_TOKEN_DURATION / 1000)),
		};
	},

	async refreshToken(req): Promise<AuthResponse> {
		// Validate input
		if (!req.refreshToken) {
			throw new ServerError(Status.INVALID_ARGUMENT, "Refresh token is required");
		}

		// Verify refresh token
		const tokenData = refreshTokens.get(req.refreshToken);
		if (!tokenData) {
			throw new ServerError(Status.UNAUTHENTICATED, "Invalid refresh token");
		}

		if (Date.now() > tokenData.expiresAt) {
			refreshTokens.delete(req.refreshToken);
			throw new ServerError(Status.UNAUTHENTICATED, "Refresh token expired");
		}

		const user = users.get(tokenData.userId);
		if (!user) {
			throw new ServerError(Status.NOT_FOUND, "User not found");
		}

		// Revoke old refresh token
		refreshTokens.delete(req.refreshToken);

		// Generate new tokens
		const accessToken = generateAccessToken(user.id);
		const refreshToken = generateRefreshToken(user.id);

		return {
			accessToken,
			refreshToken,
			expiresIn: BigInt(Math.floor(ACCESS_TOKEN_DURATION / 1000)),
			user: undefined,
		};
	},

	async validateToken(req): Promise<ValidateTokenResponse> {
		// Validate input
		if (!req.accessToken) {
			throw new ServerError(Status.INVALID_ARGUMENT, "Access token is required");
		}

		// Verify access token
		const tokenData = accessTokens.get(req.accessToken);
		if (!tokenData) {
			return { valid: false, user: undefined };
		}

		if (Date.now() > tokenData.expiresAt) {
			accessTokens.delete(req.accessToken);
			return { valid: false, user: undefined };
		}

		const user = users.get(tokenData.userId);
		if (!user) {
			return { valid: false, user: undefined };
		}

		return {
			valid: true,
			user: toProtoUser(user),
		};
	},

	async logout(req): Promise<Empty> {
		// Revoke tokens
		if (req.refreshToken) {
			refreshTokens.delete(req.refreshToken);
		}

		return {};
	},
};

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
