/**
 * Validation utilities using Zod
 *
 * Provides input validation and standardized error responses.
 */

import { z } from "zod";
import { existsSync } from "fs";

// === COMMON SCHEMAS ===

export const pathSchema = z.string().min(1, "Path required").refine(
  (p) => existsSync(p),
  (p) => ({ message: `Path not found: ${p}` })
);

export const platformSchema = z.enum(["vercel", "railway", "render", "fly", "docker"]);

export const contextSchema = z.enum(["mvp", "b2c", "b2b", "saas", "api", "internal"]);

export const modeSchema = z.enum(["automated", "guided", "plan"]);

export const frameworkSchema = z.string().min(1);

export const portSchema = z.number().int().min(1).max(65535).default(3000);

// === TOOL INPUT SCHEMAS ===

export const analyzeInputSchema = z.object({
  path: pathSchema,
});

export const recommendInputSchema = z.object({
  framework: frameworkSchema,
  has_database: z.boolean().default(false),
  complexity: z.number().int().min(1).max(5).default(2),
  context: contextSchema,
});

export const deployInputSchema = z.object({
  path: pathSchema,
  mode: modeSchema,
  context: contextSchema.optional(),
  platform: platformSchema.optional(),
});

export const dockerDeployInputSchema = z.object({
  path: pathSchema,
  image_name: z.string().min(1).regex(/^[a-z0-9][a-z0-9_.-]*$/i, "Invalid image name"),
  container_name: z.string().optional(),
  port: portSchema,
  env_vars: z.record(z.string()).optional(),
  setup_tunnel: z.boolean().default(false),
});

export const generateDockerfileInputSchema = z.object({
  path: pathSchema,
  framework: frameworkSchema,
  port: portSchema,
});

export const generateComposeInputSchema = z.object({
  path: pathSchema,
  service_name: z.string().default("app"),
  port: portSchema,
  databases: z.array(z.string()).default([]),
});

export const platformConfigInputSchema = z.object({
  platform: platformSchema,
  framework: frameworkSchema,
  service_name: z.string().default("app"),
  port: portSchema,
  has_database: z.boolean().default(false),
});

export const tunnelInputSchema = z.object({
  tunnel_name: z.string().min(1).regex(/^[a-z0-9-]+$/, "Invalid tunnel name"),
  local_port: portSchema,
  hostname: z.string().optional(),
});

// === ERROR RESPONSE ===

export interface ErrorResponse {
  error: {
    code: string;
    message: string;
    field?: string;
  };
}

export function validationError(issues: z.ZodIssue[]): ErrorResponse {
  const first = issues[0];
  return {
    error: {
      code: "VALIDATION_ERROR",
      message: first.message,
      field: first.path.join(".") || undefined,
    },
  };
}

export function notFoundError(resource: string): ErrorResponse {
  return {
    error: {
      code: "NOT_FOUND",
      message: `${resource} not found`,
    },
  };
}

export function executionError(message: string, code = "EXECUTION_ERROR"): ErrorResponse {
  return {
    error: {
      code,
      message,
    },
  };
}

// === VALIDATION HELPER ===

export type ValidationResult<T> =
  | { success: true; data: T }
  | { success: false; error: ErrorResponse };

export function validate<T>(
  schema: z.ZodSchema<T>,
  data: unknown
): ValidationResult<T> {
  const result = schema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: validationError(result.error.issues) };
}
