/**
 * Asset service implementation for Vio design tool.
 * Handles CRUD operations for project graphics (images/SVGs) and colors.
 */

import { create } from "@bufbuild/protobuf";
import type { ServiceImpl } from "@connectrpc/connect";
import { Code, ConnectError } from "@connectrpc/connect";
import { and, eq, like } from "drizzle-orm";
import sharp from "sharp";
import { db } from "../db/index.js";
import { projectAssets, projectColors } from "../db/schema/index.js";
import {
	type Asset,
	AssetSchema,
	type AssetService,
	type CreateColorRequest,
	CreateColorResponseSchema,
	type DeleteAssetRequest,
	type DeleteColorRequest,
	type GetAssetRequest,
	GetAssetResponseSchema,
	type ListAssetsRequest,
	ListAssetsResponseSchema,
	type ListColorsRequest,
	ListColorsResponseSchema,
	type ProjectColor,
	ProjectColorSchema,
	type UpdateAssetRequest,
	UpdateAssetResponseSchema,
	type UpdateColorRequest,
	UpdateColorResponseSchema,
	type UploadAssetRequest,
	UploadAssetResponseSchema,
} from "../gen/vio/v1/asset_pb.js";
import {
	EmptySchema,
	type Gradient,
	Gradient_Type,
	GradientSchema,
	GradientStopSchema,
	type Timestamp,
	TimestampSchema,
} from "../gen/vio/v1/common_pb.js";
import { startPerfSpan } from "../utils/perf-diagnostics.js";
import { notFound } from "./errors.js";

// =============================================================================
// Constants
// =============================================================================

const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10 MB

const ALLOWED_MIME_TYPES = new Set([
	"image/png",
	"image/jpeg",
	"image/gif",
	"image/webp",
	"image/svg+xml",
]);

// =============================================================================
// Helpers
// =============================================================================

function toProtoTimestamp(date: Date): Timestamp {
	return create(TimestampSchema, { millis: BigInt(date.getTime()) });
}

/** Convert DB gradient JSON to proto Gradient */
interface DbGradientStop {
	color?: number;
	offset?: number;
	opacity?: number;
}

interface DbGradient {
	type?: string;
	stops?: DbGradientStop[];
	startX?: number;
	startY?: number;
	endX?: number;
	endY?: number;
}

function dbGradientToProto(g: DbGradient): Gradient {
	return create(GradientSchema, {
		type: g.type === "radial" ? Gradient_Type.RADIAL : Gradient_Type.LINEAR,
		stops: (g.stops ?? []).map((s) =>
			create(GradientStopSchema, {
				color: s.color ?? 0,
				offset: s.offset ?? 0,
				opacity: s.opacity ?? 1.0,
			}),
		),
		startX: g.startX ?? 0,
		startY: g.startY ?? 0,
		endX: g.endX ?? 1,
		endY: g.endY ?? 1,
	});
}

function protoGradientToDb(g: Gradient): DbGradient {
	return {
		type: g.type === Gradient_Type.RADIAL ? "radial" : "linear",
		stops: g.stops.map((s) => ({
			color: s.color,
			offset: s.offset,
			opacity: s.opacity,
		})),
		startX: g.startX,
		startY: g.startY,
		endX: g.endX,
		endY: g.endY,
	};
}

/**
 * Try to extract image dimensions from binary data.
 * Supports PNG, JPEG, GIF, WebP headers, and SVG viewBox.
 */
function extractDimensions(
	data: Uint8Array,
	mimeType: string,
): { width: number; height: number } {
	if (mimeType === "image/svg+xml") {
		return extractSvgDimensions(data);
	}
	if (mimeType === "image/png") {
		return extractPngDimensions(data);
	}
	if (mimeType === "image/jpeg") {
		return extractJpegDimensions(data);
	}
	if (mimeType === "image/gif") {
		return extractGifDimensions(data);
	}
	if (mimeType === "image/webp") {
		return extractWebpDimensions(data);
	}
	return { width: 0, height: 0 };
}

function extractPngDimensions(data: Uint8Array): {
	width: number;
	height: number;
} {
	// PNG IHDR chunk starts at byte 16 (after 8-byte signature + 4-byte length + 4-byte "IHDR")
	if (data.length < 24) return { width: 0, height: 0 };
	const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
	const width = view.getUint32(16, false);
	const height = view.getUint32(20, false);
	return { width, height };
}

function extractJpegDimensions(data: Uint8Array): {
	width: number;
	height: number;
} {
	// JPEG: scan for SOF0/SOF2 markers (0xFFC0, 0xFFC2)
	const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
	let offset = 2; // skip SOI marker
	while (offset < data.length - 8) {
		const marker = view.getUint16(offset, false);
		offset += 2;
		if (marker === 0xffc0 || marker === 0xffc2) {
			// SOF marker: length(2), precision(1), height(2), width(2)
			const height = view.getUint16(offset + 3, false);
			const width = view.getUint16(offset + 5, false);
			return { width, height };
		}
		// Skip this segment
		const segmentLength = view.getUint16(offset, false);
		offset += segmentLength;
	}
	return { width: 0, height: 0 };
}

function extractGifDimensions(data: Uint8Array): {
	width: number;
	height: number;
} {
	// GIF header: 6 bytes signature, then 2 bytes width (LE), 2 bytes height (LE)
	if (data.length < 10) return { width: 0, height: 0 };
	const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
	const width = view.getUint16(6, true); // little-endian
	const height = view.getUint16(8, true);
	return { width, height };
}

function extractWebpDimensions(data: Uint8Array): {
	width: number;
	height: number;
} {
	// WebP VP8 header: RIFF(4) + size(4) + WEBP(4) + VP8 (4) + chunk_size(4) + ...
	if (data.length < 30) return { width: 0, height: 0 };
	const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
	// Check for VP8 lossy: bytes at 12-15 are "VP8 "
	const vp8Tag = String.fromCharCode(data[12], data[13], data[14], data[15]);
	if (vp8Tag === "VP8 ") {
		// VP8 bitstream: skip to frame header
		const width = view.getUint16(26, true) & 0x3fff;
		const height = view.getUint16(28, true) & 0x3fff;
		return { width, height };
	}
	// VP8L (lossless): tag is "VP8L"
	if (vp8Tag === "VP8L") {
		const bits = view.getUint32(21, true);
		const width = (bits & 0x3fff) + 1;
		const height = ((bits >> 14) & 0x3fff) + 1;
		return { width, height };
	}
	return { width: 0, height: 0 };
}

function extractSvgDimensions(data: Uint8Array): {
	width: number;
	height: number;
} {
	const text = new TextDecoder().decode(data);
	// Try viewBox first
	const viewBoxMatch = text.match(/viewBox\s*=\s*"([^"]+)"/i);
	if (viewBoxMatch) {
		const parts = viewBoxMatch[1].trim().split(/[\s,]+/);
		if (parts.length === 4) {
			const width = Math.round(Number.parseFloat(parts[2]));
			const height = Math.round(Number.parseFloat(parts[3]));
			if (!Number.isNaN(width) && !Number.isNaN(height)) {
				return { width, height };
			}
		}
	}
	// Try width/height attributes
	const widthMatch = text.match(/\bwidth\s*=\s*"(\d+(?:\.\d+)?)"/i);
	const heightMatch = text.match(/\bheight\s*=\s*"(\d+(?:\.\d+)?)"/i);
	if (widthMatch && heightMatch) {
		return {
			width: Math.round(Number.parseFloat(widthMatch[1])),
			height: Math.round(Number.parseFloat(heightMatch[1])),
		};
	}
	return { width: 100, height: 100 }; // Default for SVGs without dimensions
}

/**
 * Convert a DB asset row to a protobuf Asset message.
 * @param includeData Whether to include the full binary data (for GetAsset).
 */
function toProtoAsset(
	row: typeof projectAssets.$inferSelect,
	includeData = false,
): Asset {
	return create(AssetSchema, {
		id: row.id,
		projectId: row.projectId,
		name: row.name,
		path: row.path ?? "",
		mimeType: row.mimeType,
		width: row.width,
		height: row.height,
		fileSize: row.fileSize,
		thumbnail: row.thumbnail
			? new Uint8Array(row.thumbnail)
			: new Uint8Array(0),
		data: includeData ? new Uint8Array(row.data) : new Uint8Array(0),
		createdAt: toProtoTimestamp(row.createdAt),
		updatedAt: toProtoTimestamp(row.updatedAt),
	});
}

/**
 * Convert a DB color row to a protobuf ProjectColor message.
 */
function toProtoColor(row: typeof projectColors.$inferSelect): ProjectColor {
	return create(ProjectColorSchema, {
		id: row.id,
		projectId: row.projectId,
		name: row.name,
		path: row.path ?? "",
		color: row.color ?? "",
		opacity: row.opacity,
		gradient: row.gradient
			? dbGradientToProto(row.gradient as DbGradient)
			: undefined,
		createdAt: toProtoTimestamp(row.createdAt),
		updatedAt: toProtoTimestamp(row.updatedAt),
	});
}

// =============================================================================
// Service Implementation
// =============================================================================

export const assetServiceImpl: ServiceImpl<typeof AssetService> = {
	// ─── Upload Asset ──────────────────────────────────────────────────────

	async uploadAsset(req: UploadAssetRequest) {
		const perfSpan = startPerfSpan("asset.uploadAsset", {
			projectId: req.projectId,
			mimeType: req.mimeType,
			inputBytes: req.data?.length ?? 0,
		});
		let perfError: unknown;

		try {
			// Validate
			if (!req.projectId) {
				throw new ConnectError("project_id is required", Code.InvalidArgument);
			}
			if (!req.name) {
				throw new ConnectError("name is required", Code.InvalidArgument);
			}
			if (!req.mimeType || !ALLOWED_MIME_TYPES.has(req.mimeType)) {
				throw new ConnectError(
					`Unsupported MIME type: ${req.mimeType}. Allowed: ${[...ALLOWED_MIME_TYPES].join(", ")}`,
					Code.InvalidArgument,
				);
			}
			if (!req.data || req.data.length === 0) {
				throw new ConnectError("data is required", Code.InvalidArgument);
			}
			if (req.data.length > MAX_FILE_SIZE) {
				throw new ConnectError(
					`File too large: ${req.data.length} bytes (max ${MAX_FILE_SIZE} bytes)`,
					Code.InvalidArgument,
				);
			}

			// Extract dimensions
			const dims = extractDimensions(req.data, req.mimeType);

			// Generate thumbnail
			let thumbnailBuffer: Buffer | null = null;
			if (req.mimeType !== "image/svg+xml") {
				try {
					thumbnailBuffer = await sharp(Buffer.from(req.data))
						.resize(200, 200, { fit: "inside", withoutEnlargement: true })
						.png({ quality: 80 })
						.toBuffer();
				} catch (e) {
					console.warn("Thumbnail generation failed:", e);
				}
			} else {
				// SVGs are typically small; store original as thumbnail
				thumbnailBuffer = Buffer.from(req.data);
			}

			// Insert into DB
			const [inserted] = await db
				.insert(projectAssets)
				.values({
					projectId: req.projectId,
					name: req.name,
					path: req.path || null,
					mimeType: req.mimeType,
					width: dims.width,
					height: dims.height,
					data: Buffer.from(req.data),
					thumbnail: thumbnailBuffer,
					fileSize: req.data.length,
				})
				.returning();

			return create(UploadAssetResponseSchema, {
				asset: toProtoAsset(inserted),
			});
		} catch (error) {
			perfError = error;
			throw error;
		} finally {
			await perfSpan.finish(undefined, perfError);
		}
	},

	// ─── List Assets ───────────────────────────────────────────────────────

	async listAssets(req: ListAssetsRequest) {
		const perfSpan = startPerfSpan("asset.listAssets", {
			projectId: req.projectId,
			pathPrefix: req.pathPrefix,
		});
		let assetCount = 0;
		let perfError: unknown;

		try {
			if (!req.projectId) {
				throw new ConnectError("project_id is required", Code.InvalidArgument);
			}

			const conditions = [eq(projectAssets.projectId, req.projectId)];
			if (req.pathPrefix) {
				conditions.push(like(projectAssets.path, `${req.pathPrefix}%`));
			}

			const rows = await db
				.select({
					id: projectAssets.id,
					projectId: projectAssets.projectId,
					name: projectAssets.name,
					path: projectAssets.path,
					mimeType: projectAssets.mimeType,
					width: projectAssets.width,
					height: projectAssets.height,
					fileSize: projectAssets.fileSize,
					thumbnail: projectAssets.thumbnail,
					createdAt: projectAssets.createdAt,
					updatedAt: projectAssets.updatedAt,
				})
				.from(projectAssets)
				.where(and(...conditions));
			assetCount = rows.length;

			// Map rows to proto (without full data)
			const assets = rows.map((row) =>
				create(AssetSchema, {
					id: row.id,
					projectId: row.projectId,
					name: row.name,
					path: row.path ?? "",
					mimeType: row.mimeType,
					width: row.width,
					height: row.height,
					fileSize: row.fileSize,
					thumbnail: row.thumbnail
						? new Uint8Array(row.thumbnail)
						: new Uint8Array(0),
					data: new Uint8Array(0), // Don't include full data in list
					createdAt: toProtoTimestamp(row.createdAt),
					updatedAt: toProtoTimestamp(row.updatedAt),
				}),
			);

			return create(ListAssetsResponseSchema, { assets });
		} catch (error) {
			perfError = error;
			throw error;
		} finally {
			await perfSpan.finish({ assetCount }, perfError);
		}
	},

	// ─── Get Asset ─────────────────────────────────────────────────────────

	async getAsset(req: GetAssetRequest) {
		const perfSpan = startPerfSpan("asset.getAsset", {
			assetId: req.id,
		});
		let returnedBytes = 0;
		let mimeType: string | null = null;
		let perfError: unknown;

		try {
			if (!req.id) {
				throw new ConnectError("id is required", Code.InvalidArgument);
			}

			const [row] = await db
				.select()
				.from(projectAssets)
				.where(eq(projectAssets.id, req.id))
				.limit(1);

			if (!row) {
				throw notFound(`Asset ${req.id} not found`);
			}
			returnedBytes = row.fileSize;
			mimeType = row.mimeType;

			return create(GetAssetResponseSchema, {
				asset: toProtoAsset(row, true), // Include full data
			});
		} catch (error) {
			perfError = error;
			throw error;
		} finally {
			await perfSpan.finish(
				{
					returnedBytes,
					mimeType,
				},
				perfError,
			);
		}
	},

	// ─── Update Asset ──────────────────────────────────────────────────────

	async updateAsset(req: UpdateAssetRequest) {
		if (!req.id) {
			throw new ConnectError("id is required", Code.InvalidArgument);
		}

		const updates: Record<string, unknown> = {
			updatedAt: new Date(),
		};

		if (req.name !== undefined && req.name !== null) {
			updates.name = req.name;
		}
		if (req.path !== undefined && req.path !== null) {
			updates.path = req.path || null; // Empty string → null (ungrouped)
		}

		const [updated] = await db
			.update(projectAssets)
			.set(updates)
			.where(eq(projectAssets.id, req.id))
			.returning();

		if (!updated) {
			throw notFound(`Asset ${req.id} not found`);
		}

		return create(UpdateAssetResponseSchema, {
			asset: toProtoAsset(updated),
		});
	},

	// ─── Delete Asset ──────────────────────────────────────────────────────

	async deleteAsset(req: DeleteAssetRequest) {
		if (!req.id) {
			throw new ConnectError("id is required", Code.InvalidArgument);
		}

		const result = await db
			.delete(projectAssets)
			.where(eq(projectAssets.id, req.id))
			.returning({ id: projectAssets.id });

		if (result.length === 0) {
			throw notFound(`Asset ${req.id} not found`);
		}

		return create(EmptySchema, {});
	},

	// ─── Create Color ──────────────────────────────────────────────────────

	async createColor(req: CreateColorRequest) {
		if (!req.projectId) {
			throw new ConnectError("project_id is required", Code.InvalidArgument);
		}
		if (!req.name) {
			throw new ConnectError("name is required", Code.InvalidArgument);
		}

		const [inserted] = await db
			.insert(projectColors)
			.values({
				projectId: req.projectId,
				name: req.name,
				path: req.path || null,
				color: req.color || null,
				opacity: req.opacity || 1.0,
				gradient: req.gradient ? protoGradientToDb(req.gradient) : null,
			})
			.returning();

		return create(CreateColorResponseSchema, {
			color: toProtoColor(inserted),
		});
	},

	// ─── List Colors ───────────────────────────────────────────────────────

	async listColors(req: ListColorsRequest) {
		const perfSpan = startPerfSpan("asset.listColors", {
			projectId: req.projectId,
			pathPrefix: req.pathPrefix,
		});
		let colorCount = 0;
		let perfError: unknown;

		try {
			if (!req.projectId) {
				throw new ConnectError("project_id is required", Code.InvalidArgument);
			}

			const conditions = [eq(projectColors.projectId, req.projectId)];
			if (req.pathPrefix) {
				conditions.push(like(projectColors.path, `${req.pathPrefix}%`));
			}

			const rows = await db
				.select()
				.from(projectColors)
				.where(and(...conditions));
			colorCount = rows.length;

			return create(ListColorsResponseSchema, {
				colors: rows.map(toProtoColor),
			});
		} catch (error) {
			perfError = error;
			throw error;
		} finally {
			await perfSpan.finish({ colorCount }, perfError);
		}
	},

	// ─── Update Color ──────────────────────────────────────────────────────

	async updateColor(req: UpdateColorRequest) {
		if (!req.id) {
			throw new ConnectError("id is required", Code.InvalidArgument);
		}

		const updates: Record<string, unknown> = {
			updatedAt: new Date(),
		};

		if (req.name !== undefined && req.name !== null) {
			updates.name = req.name;
		}
		if (req.path !== undefined && req.path !== null) {
			updates.path = req.path || null;
		}
		if (req.color !== undefined && req.color !== null) {
			updates.color = req.color;
		}
		if (req.opacity !== undefined && req.opacity !== null) {
			updates.opacity = req.opacity;
		}
		if (req.gradient !== undefined) {
			updates.gradient = req.gradient ? protoGradientToDb(req.gradient) : null;
		}

		const [updated] = await db
			.update(projectColors)
			.set(updates)
			.where(eq(projectColors.id, req.id))
			.returning();

		if (!updated) {
			throw notFound(`Color ${req.id} not found`);
		}

		return create(UpdateColorResponseSchema, {
			color: toProtoColor(updated),
		});
	},

	// ─── Delete Color ──────────────────────────────────────────────────────

	async deleteColor(req: DeleteColorRequest) {
		if (!req.id) {
			throw new ConnectError("id is required", Code.InvalidArgument);
		}

		const result = await db
			.delete(projectColors)
			.where(eq(projectColors.id, req.id))
			.returning({ id: projectColors.id });

		if (result.length === 0) {
			throw notFound(`Color ${req.id} not found`);
		}

		return create(EmptySchema, {});
	},
};
