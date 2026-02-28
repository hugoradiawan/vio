/**
 * Error utilities for ConnectRPC services.
 * Provides convenient wrappers for common error codes.
 */

import { Code, ConnectError } from "@connectrpc/connect";

// Re-export for service implementations
export { Code, ConnectError };

/**
 * Create a NOT_FOUND error
 */
export function notFound(message: string): ConnectError {
	return new ConnectError(message, Code.NotFound);
}

/**
 * Create an INVALID_ARGUMENT error
 */
export function invalidArgument(message: string): ConnectError {
	return new ConnectError(message, Code.InvalidArgument);
}

/**
 * Create an ALREADY_EXISTS error
 */
export function alreadyExists(message: string): ConnectError {
	return new ConnectError(message, Code.AlreadyExists);
}

/**
 * Create an UNAUTHENTICATED error
 */
export function unauthenticated(message: string): ConnectError {
	return new ConnectError(message, Code.Unauthenticated);
}

/**
 * Create an UNAVAILABLE error
 */
export function unavailable(message: string): ConnectError {
	return new ConnectError(message, Code.Unavailable);
}

/**
 * Create a PERMISSION_DENIED error
 */
export function permissionDenied(message: string): ConnectError {
	return new ConnectError(message, Code.PermissionDenied);
}

/**
 * Create an INTERNAL error
 */
export function internal(message: string): ConnectError {
	return new ConnectError(message, Code.Internal);
}

/**
 * Create a FAILED_PRECONDITION error
 */
export function failedPrecondition(message: string): ConnectError {
	return new ConnectError(message, Code.FailedPrecondition);
}

/**
 * Create an ABORTED error
 */
export function aborted(message: string): ConnectError {
	return new ConnectError(message, Code.Aborted);
}
