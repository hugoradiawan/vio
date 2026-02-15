/**
 * Auth service implementation for ConnectRPC.
 *
 * Uses PostgreSQL (Drizzle) for user persistence and bcrypt for password hashing.
 * Access tokens are kept in-memory (short-lived, 15min TTL).
 * Refresh tokens are persisted in the database.
 */

import { create } from "@bufbuild/protobuf";
import type { ServiceImpl } from "@connectrpc/connect";
import bcrypt from "bcryptjs";
import { eq } from "drizzle-orm";
import { nanoid } from "nanoid";
import { db, schema } from "../db/index.js";
import {
	AuthResponseSchema,
	AuthService,
	UserSchema,
	ValidateTokenResponseSchema,
	type AuthResponse,
	type User,
	type ValidateTokenResponse,
} from "../gen/vio/v1/auth_pb.js";
import {
	EmptySchema,
	TimestampSchema,
	type Empty,
	type Timestamp,
} from "../gen/vio/v1/common_pb.js";
import {
	alreadyExists,
	invalidArgument,
	notFound,
	unauthenticated,
} from "./errors.js";

// ============================================================================
// In-Memory Access Token Store (short-lived, lost on restart is OK)
// ============================================================================

interface StoredToken {
	userId: string;
	expiresAt: number;
}

const accessTokens = new Map<string, StoredToken>();

// Token validity durations (configurable via environment variables)
function getDurationMsFromEnv(envVar: string, defaultMs: number): number {
	const raw = process.env[envVar];
	if (!raw) {
		return defaultMs;
	}
	const parsed = Number(raw);
	if (!Number.isFinite(parsed) || parsed <= 0) {
		return defaultMs;
	}
	return parsed;
}

const ACCESS_TOKEN_DURATION = getDurationMsFromEnv(
	"ACCESS_TOKEN_DURATION_MS",
	15 * 60 * 1000, // 15 minutes
);
const REFRESH_TOKEN_DURATION = getDurationMsFromEnv(
	"REFRESH_TOKEN_DURATION_MS",
	7 * 24 * 60 * 60 * 1000, // 7 days
);
const BCRYPT_ROUNDS = 12;

// ============================================================================
// Helper Functions
// ============================================================================

function toProtoTimestamp(date: Date): Timestamp {
	return create(TimestampSchema, {
		millis: BigInt(date.getTime()),
	});
}

function toProtoUser(stored: {
	id: string;
	email: string;
	name: string;
	avatarUrl: string | null;
	createdAt: Date;
}): User {
	return create(UserSchema, {
		id: stored.id,
		email: stored.email,
		name: stored.name,
		avatarUrl: stored.avatarUrl ?? undefined,
		createdAt: toProtoTimestamp(stored.createdAt),
	});
}

function generateAccessToken(userId: string): string {
	const token = `vio_at_${nanoid(32)}`;
	accessTokens.set(token, {
		userId,
		expiresAt: Date.now() + ACCESS_TOKEN_DURATION,
	});
	return token;
}

async function generateRefreshToken(userId: string): Promise<string> {
	const token = `vio_rt_${nanoid(48)}`;
	await db.insert(schema.refreshTokens).values({
		token,
		userId,
		expiresAt: new Date(Date.now() + REFRESH_TOKEN_DURATION),
	});
	return token;
}

// ============================================================================
// Service Implementation
// ============================================================================

export const authServiceImpl: ServiceImpl<typeof AuthService> = {
	async register(req): Promise<AuthResponse> {
		// Validate input
		if (!req.email || !req.password || !req.name) {
			throw invalidArgument("Email, password, and name are required");
		}

		if (req.password.length < 8) {
			throw invalidArgument("Password must be at least 8 characters");
		}

		// Check if email is already taken
		const existing = await db.query.users.findFirst({
			where: eq(schema.users.email, req.email.toLowerCase()),
		});
		if (existing) {
			throw alreadyExists("Email already registered");
		}

		// Create user
		const passwordHash = await bcrypt.hash(req.password, BCRYPT_ROUNDS);
		const [user] = await db
			.insert(schema.users)
			.values({
				email: req.email.toLowerCase(),
				name: req.name,
				passwordHash,
			})
			.returning();

		// Generate tokens
		const accessToken = generateAccessToken(user.id);
		const refreshToken = await generateRefreshToken(user.id);

		return create(AuthResponseSchema, {
			user: toProtoUser(user),
			accessToken,
			refreshToken,
			expiresIn: BigInt(Math.floor(ACCESS_TOKEN_DURATION / 1000)),
		});
	},

	async login(req): Promise<AuthResponse> {
		// Validate input
		if (!req.email || !req.password) {
			throw invalidArgument("Email and password are required");
		}

		// Find user
		const user = await db.query.users.findFirst({
			where: eq(schema.users.email, req.email.toLowerCase()),
		});
		if (!user) {
			throw unauthenticated("Invalid email or password");
		}

		// Verify password
		const valid = await bcrypt.compare(req.password, user.passwordHash);
		if (!valid) {
			throw unauthenticated("Invalid email or password");
		}

		// Generate tokens
		const accessToken = generateAccessToken(user.id);
		const refreshToken = await generateRefreshToken(user.id);

		return create(AuthResponseSchema, {
			user: toProtoUser(user),
			accessToken,
			refreshToken,
			expiresIn: BigInt(Math.floor(ACCESS_TOKEN_DURATION / 1000)),
		});
	},

	async refreshToken(req): Promise<AuthResponse> {
		// Validate input
		if (!req.refreshToken) {
			throw invalidArgument("Refresh token is required");
		}

		// Find the refresh token in DB
		const tokenRecord = await db.query.refreshTokens.findFirst({
			where: eq(schema.refreshTokens.token, req.refreshToken),
		});
		if (!tokenRecord) {
			throw unauthenticated("Invalid refresh token");
		}

		if (new Date() > tokenRecord.expiresAt) {
			// Clean up expired token
			await db
				.delete(schema.refreshTokens)
				.where(eq(schema.refreshTokens.id, tokenRecord.id));
			throw unauthenticated("Refresh token expired");
		}

		const user = await db.query.users.findFirst({
			where: eq(schema.users.id, tokenRecord.userId),
			// Preserve historical contract: refreshToken does not return user data
			// user: undefined,
		});
		if (!user) {
			throw notFound("User not found");
		}

		// Revoke old refresh token
		await db
			.delete(schema.refreshTokens)
			.where(eq(schema.refreshTokens.id, tokenRecord.id));

		// Generate new tokens
		const accessToken = generateAccessToken(user.id);
		const refreshToken = await generateRefreshToken(user.id);

		return create(AuthResponseSchema, {
			accessToken,
			refreshToken,
			expiresIn: BigInt(Math.floor(ACCESS_TOKEN_DURATION / 1000)),
			user: toProtoUser(user),
		});
	},

	async validateToken(req): Promise<ValidateTokenResponse> {
		// Validate input
		if (!req.accessToken) {
			throw invalidArgument("Access token is required");
		}

		// Verify access token (in-memory)
		const tokenData = accessTokens.get(req.accessToken);
		if (!tokenData) {
			return create(ValidateTokenResponseSchema, {
				valid: false,
				user: undefined,
			});
		}

		if (Date.now() > tokenData.expiresAt) {
			accessTokens.delete(req.accessToken);
			return create(ValidateTokenResponseSchema, {
				valid: false,
				user: undefined,
			});
		}

		const user = await db.query.users.findFirst({
			where: eq(schema.users.id, tokenData.userId),
		});
		if (!user) {
			return create(ValidateTokenResponseSchema, {
				valid: false,
				user: undefined,
			});
		}

		return create(ValidateTokenResponseSchema, {
			valid: true,
			user: toProtoUser(user),
		});
	},

	async logout(req): Promise<Empty> {
		// Revoke refresh token from DB
		if (req.refreshToken) {
			await db
				.delete(schema.refreshTokens)
				.where(eq(schema.refreshTokens.token, req.refreshToken));
		}

		return create(EmptySchema, {});
	},
};

// ============================================================================
// Token Validation Middleware Helper
// ============================================================================

export async function validateAccessToken(
	token: string | undefined,
): Promise<{ id: string; email: string; name: string } | null> {
	if (!token) return null;

	// Remove "Bearer " prefix if present
	const cleanToken = token.startsWith("Bearer ") ? token.slice(7) : token;

	const tokenData = accessTokens.get(cleanToken);
	if (!tokenData) return null;

	if (Date.now() > tokenData.expiresAt) {
		accessTokens.delete(cleanToken);
		return null;
	}

	const user = await db.query.users.findFirst({
		where: eq(schema.users.id, tokenData.userId),
	});
	if (!user) return null;

	return { id: user.id, email: user.email, name: user.name };
}

// ============================================================================
// Admin User Bootstrap
// ============================================================================

const ADMIN_EMAIL = "admin@vio.dev";
const ADMIN_PASSWORD = "admin123";
const ADMIN_NAME = "Admin";

/**
 * Ensures a default admin user exists.
 * Called on server startup — creates the admin only if no users exist.
 */
export async function ensureAdminUser(): Promise<void> {
	const existingUsers = await db.query.users.findFirst();
	if (existingUsers) return; // Users exist, skip

	const passwordHash = await bcrypt.hash(ADMIN_PASSWORD, BCRYPT_ROUNDS);
	await db.insert(schema.users).values({
		email: ADMIN_EMAIL,
		name: ADMIN_NAME,
		passwordHash,
		isAdmin: true,
	});

	console.log(`
✅ Default admin user created:
   Email:    ${ADMIN_EMAIL}
   Password: ${ADMIN_PASSWORD}
   ⚠️  Change this password after first login!
`);
}
