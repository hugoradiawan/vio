import { appendFile, mkdir } from "node:fs/promises";
import path from "node:path";

interface PerfLogEntry {
	timestamp: string;
	operation: string;
	durationMs: number;
	context?: Record<string, unknown>;
	result?: Record<string, unknown>;
	error?: {
		name: string;
		message: string;
	};
}

const enabledFlag = process.env.PERF_DIAGNOSTICS?.toLowerCase();
const PERF_DIAGNOSTICS_ENABLED = enabledFlag === "1" || enabledFlag === "true";

const PERF_DIAGNOSTICS_FILE =
	process.env.PERF_DIAGNOSTICS_FILE ||
	path.resolve(process.cwd(), "logs/perf-diagnostics.jsonl");

let logSetupPromise: Promise<unknown> | null = null;

function serializeError(error: unknown): { name: string; message: string } {
	if (error instanceof Error) {
		return {
			name: error.name,
			message: error.message,
		};
	}

	return {
		name: "UnknownError",
		message: String(error),
	};
}

async function ensureLogFileReady(): Promise<void> {
	if (!logSetupPromise) {
		logSetupPromise = mkdir(path.dirname(PERF_DIAGNOSTICS_FILE), {
			recursive: true,
		});
	}

	await logSetupPromise;
}

async function writePerfLog(entry: PerfLogEntry): Promise<void> {
	if (!PERF_DIAGNOSTICS_ENABLED) {
		return;
	}

	await ensureLogFileReady();
	await appendFile(PERF_DIAGNOSTICS_FILE, `${JSON.stringify(entry)}\n`, "utf8");
}

interface PerfSpan {
	finish: (result?: Record<string, unknown>, error?: unknown) => Promise<void>;
}

export function startPerfSpan(
	operation: string,
	context?: Record<string, unknown>,
): PerfSpan {
	const startNanos = process.hrtime.bigint();

	return {
		finish: async (
			result?: Record<string, unknown>,
			error?: unknown,
		): Promise<void> => {
			if (!PERF_DIAGNOSTICS_ENABLED) {
				return;
			}

			const durationMs =
				Number(process.hrtime.bigint() - startNanos) / 1_000_000;

			await writePerfLog({
				timestamp: new Date().toISOString(),
				operation,
				durationMs: Number(durationMs.toFixed(3)),
				context,
				result,
				error: error ? serializeError(error) : undefined,
			});
		},
	};
}

export function getPerfDiagnosticsConfig(): {
	enabled: boolean;
	filePath: string;
} {
	return {
		enabled: PERF_DIAGNOSTICS_ENABLED,
		filePath: PERF_DIAGNOSTICS_FILE,
	};
}
