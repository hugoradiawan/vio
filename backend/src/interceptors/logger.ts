/**
 * ConnectRPC Logging Interceptor
 *
 * Logs every RPC call with: service/method, request/response data,
 * duration (ms), headers, status, and errors.
 *
 * LOG_LEVEL controls verbosity via the RPC_LOG_LEVEL env var:
 *   "verbose"  — Full request/response bodies, headers, timing
 *   "smart"    — Compact bodies (arrays summarized, large fields trimmed), headers, timing
 *   "minimal"  — Method name + status + timing only (no headers or bodies)
 *   "off"      — Logging disabled entirely
 */

import { Code, ConnectError, type Interceptor } from "@connectrpc/connect";

// ── Configuration ──────────────────────────────────────────────────────────

type LogLevel = "off" | "minimal" | "smart" | "verbose";

const LOG_LEVEL: LogLevel = (() => {
	const env = (process.env.RPC_LOG_LEVEL ?? "smart").toLowerCase();
	if (["off", "minimal", "smart", "verbose"].includes(env)) {
		return env as LogLevel;
	}
	// Legacy support: ENABLE_RPC_LOGGING=false → off
	if (process.env.ENABLE_RPC_LOGGING === "false") return "off";
	return "smart";
})();

const SMART_MAX_BODY = 4000;
const VERBOSE_MAX_BODY = 20000;

// ── ANSI Colors ────────────────────────────────────────────────────────────

const c = {
	reset: "\x1b[0m",
	dim: "\x1b[2m",
	bold: "\x1b[1m",
	cyan: "\x1b[36m",
	green: "\x1b[32m",
	red: "\x1b[31m",
	yellow: "\x1b[33m",
	magenta: "\x1b[35m",
	white: "\x1b[37m",
} as const;

// ── Helpers ────────────────────────────────────────────────────────────────

/** Extract ServiceName/MethodName from the URL path */
function parseRpcPath(url: string): { service: string; method: string } {
	// URL format: /package.ServiceName/MethodName
	const parts = url.split("/").filter(Boolean);
	if (parts.length >= 2) {
		const serviceFull = parts[parts.length - 2];
		// Strip package prefix (e.g., "vio.v1.CanvasService" → "CanvasService")
		const service = serviceFull.split(".").pop() ?? serviceFull;
		const method = parts[parts.length - 1];
		return { service, method };
	}
	return { service: "Unknown", method: url };
}

/** Sanitize headers for logging — redact sensitive values */
function sanitizeHeaders(headers: Headers): Record<string, string> {
	const result: Record<string, string> = {};
	const interestingHeaders = [
		"content-type",
		"connect-protocol-version",
		"connect-timeout-ms",
		"x-grpc-web",
		"x-user-agent",
		"user-agent",
		"authorization",
	];

	for (const key of interestingHeaders) {
		const value = headers.get(key);
		if (value != null) {
			if (key === "authorization") {
				// Redact token value
				result[key] = value.startsWith("Bearer ")
					? "Bearer ***"
					: "***";
			} else {
				result[key] = value;
			}
		}
	}
	return result;
}

/** Base replacer: handles BigInt and binary for all modes */
function baseReplacer(key: string, value: unknown): unknown {
	if (key === "$typeName") return undefined;
	if (typeof value === "bigint") return value.toString();
	if (value instanceof Uint8Array) return `<binary ${value.byteLength} bytes>`;
	return value;
}

/** Smart replacer: compact summaries for arrays and long strings */
function smartReplacer(key: string, value: unknown): unknown {
	const base = baseReplacer(key, value);
	if (base !== value) return base;

	// Truncate long string fields
	if (typeof value === "string" && value.length > 200) {
		return `${value.slice(0, 100)}… <${value.length} chars>`;
	}
	// Summarize large arrays
	if (Array.isArray(value) && value.length > 3) {
		if (
			value.length > 0 &&
			typeof value[0] === "object" &&
			value[0] !== null &&
			"id" in value[0]
		) {
			const ids = value
				.slice(0, 3)
				.map((v) => (v as Record<string, unknown>).name ?? (v as Record<string, unknown>).id);
			const suffix = value.length > 3 ? `, +${value.length - 3} more` : "";
			return `[${value.length} items: ${ids.join(", ")}${suffix}]`;
		}
		return [...value.slice(0, 3), `… +${value.length - 3} more`];
	}
	return value;
}

/** Format a message body according to the current log level */
function formatBody(message: unknown, level: LogLevel): string {
	if (message == null) return "null";

	const replacer = level === "verbose" ? baseReplacer : smartReplacer;
	const maxLen = level === "verbose" ? VERBOSE_MAX_BODY : SMART_MAX_BODY;

	try {
		const serialized = JSON.stringify(message, replacer as (key: string, value: unknown) => unknown, 2);

		if (serialized.length > maxLen) {
			return `${serialized.slice(0, maxLen)}… <truncated>`;
		}
		return serialized;
	} catch {
		return "<unable to serialize>";
	}
}

/** Map ConnectRPC error code to its name */
function codeName(code: Code): string {
	return Code[code] ?? `UNKNOWN(${code})`;
}

function timestamp(): string {
	return new Date().toISOString().slice(11, 23); // HH:mm:ss.SSS
}

// ── Interceptor ────────────────────────────────────────────────────────────

export const loggingInterceptor: Interceptor = (next) => async (req) => {
	if (LOG_LEVEL === "off") {
		return await next(req);
	}

	const start = performance.now();
	const { service, method } = parseRpcPath(req.url);
	const label = `${service}/${method}`;
	const isStreaming = req.stream;
	const showHeaders = LOG_LEVEL !== "minimal";
	const showBodies = LOG_LEVEL === "smart" || LOG_LEVEL === "verbose";

	// ── Request log ──
	const lines: string[] = [];
	lines.push(
		`${c.dim}${timestamp()}${c.reset} ${c.cyan}${c.bold}← ${label}${c.reset}${isStreaming ? ` ${c.magenta}[stream]${c.reset}` : ""}`,
	);

	if (showHeaders) {
		const headers = sanitizeHeaders(req.header);
		lines.push(
			`  ${c.dim}Headers:${c.reset} ${c.dim}${JSON.stringify(headers)}${c.reset}`,
		);
	}

	if (showBodies && !isStreaming) {
		lines.push(
			`  ${c.dim}Body:${c.reset} ${formatBody(req.message, LOG_LEVEL)}`,
		);
	}

	console.log(lines.join("\n"));

	// ── Execute RPC ──
	try {
		const res = await next(req);
		const durationMs = (performance.now() - start).toFixed(1);

		// ── Response log ──
		const resLines: string[] = [];

		if (!res.stream) {
			resLines.push(
				`${c.dim}${timestamp()}${c.reset} ${c.green}${c.bold}→ ${label}${c.reset} ${c.green}OK${c.reset} ${c.dim}${durationMs}ms${c.reset}`,
			);
			if (showBodies) {
				resLines.push(
					`  ${c.dim}Body:${c.reset} ${formatBody(res.message, LOG_LEVEL)}`,
				);
			}
		} else {
			// For streaming responses, wrap the async iterable to count messages
			const originalStream = res.message;
			let messageCount = 0;

			async function* countingStream(
				stream: AsyncIterable<unknown>,
			): AsyncIterable<unknown> {
				for await (const msg of stream) {
					messageCount++;
					yield msg;
				}
				// Log after stream completes
				const streamDuration = (performance.now() - start).toFixed(1);
				console.log(
					`${c.dim}${timestamp()}${c.reset} ${c.green}${c.bold}→ ${label}${c.reset} ${c.green}OK${c.reset} ${c.magenta}[${messageCount} msgs]${c.reset} ${c.dim}${streamDuration}ms${c.reset}`,
				);
			}

			resLines.push(
				`${c.dim}${timestamp()}${c.reset} ${c.green}→ ${label}${c.reset} ${c.magenta}[stream started]${c.reset} ${c.dim}${durationMs}ms${c.reset}`,
			);

			console.log(resLines.join("\n"));
			return {
				...res,
				message: countingStream(
					originalStream as AsyncIterable<unknown>,
				),
			} as typeof res;
		}

		console.log(resLines.join("\n"));
		return res;
	} catch (error) {
		const durationMs = (performance.now() - start).toFixed(1);

		if (error instanceof ConnectError) {
			console.log(
				`${c.dim}${timestamp()}${c.reset} ${c.red}${c.bold}→ ${label} ERROR${c.reset} ${c.red}${codeName(error.code)}${c.reset}: ${error.message} ${c.dim}${durationMs}ms${c.reset}`,
			);
		} else {
			console.log(
				`${c.dim}${timestamp()}${c.reset} ${c.red}${c.bold}→ ${label} ERROR${c.reset} ${c.red}INTERNAL${c.reset}: ${error instanceof Error ? error.message : String(error)} ${c.dim}${durationMs}ms${c.reset}`,
			);
		}

		throw error;
	}
};
