/**
 * Validation utilities tests
 */

import { describe, it, expect } from "vitest";
import {
  validate,
  validationError,
  notFoundError,
  executionError,
  platformSchema,
  contextSchema,
  modeSchema,
  portSchema,
} from "../src/utils/validation.js";
import { z } from "zod";

describe("validation utilities", () => {
  describe("validate()", () => {
    const testSchema = z.object({
      name: z.string().min(1),
      count: z.number().int().positive(),
    });

    it("returns success with valid data", () => {
      const result = validate(testSchema, { name: "test", count: 5 });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe("test");
        expect(result.data.count).toBe(5);
      }
    });

    it("returns error with invalid data", () => {
      const result = validate(testSchema, { name: "", count: 5 });
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.error.code).toBe("VALIDATION_ERROR");
      }
    });

    it("returns error with missing required fields", () => {
      const result = validate(testSchema, { name: "test" });
      expect(result.success).toBe(false);
    });

    it("returns error with wrong types", () => {
      const result = validate(testSchema, { name: "test", count: "five" });
      expect(result.success).toBe(false);
    });
  });

  describe("validationError()", () => {
    it("formats Zod issues correctly", () => {
      const issues: z.ZodIssue[] = [
        {
          code: "too_small",
          minimum: 1,
          type: "string",
          inclusive: true,
          exact: false,
          message: "String must contain at least 1 character(s)",
          path: ["name"],
        },
      ];

      const error = validationError(issues);
      expect(error.error.code).toBe("VALIDATION_ERROR");
      expect(error.error.message).toBe("String must contain at least 1 character(s)");
      expect(error.error.field).toBe("name");
    });

    it("handles nested paths", () => {
      const issues: z.ZodIssue[] = [
        {
          code: "invalid_type",
          expected: "string",
          received: "number",
          message: "Expected string",
          path: ["config", "database", "host"],
        },
      ];

      const error = validationError(issues);
      expect(error.error.field).toBe("config.database.host");
    });
  });

  describe("notFoundError()", () => {
    it("creates not found error", () => {
      const error = notFoundError("Project");
      expect(error.error.code).toBe("NOT_FOUND");
      expect(error.error.message).toBe("Project not found");
    });
  });

  describe("executionError()", () => {
    it("creates execution error with default code", () => {
      const error = executionError("Command failed");
      expect(error.error.code).toBe("EXECUTION_ERROR");
      expect(error.error.message).toBe("Command failed");
    });

    it("creates execution error with custom code", () => {
      const error = executionError("Docker not running", "DOCKER_ERROR");
      expect(error.error.code).toBe("DOCKER_ERROR");
    });
  });

  describe("common schemas", () => {
    it("platformSchema validates platforms", () => {
      expect(platformSchema.safeParse("vercel").success).toBe(true);
      expect(platformSchema.safeParse("railway").success).toBe(true);
      expect(platformSchema.safeParse("render").success).toBe(true);
      expect(platformSchema.safeParse("fly").success).toBe(true);
      expect(platformSchema.safeParse("docker").success).toBe(true);
      expect(platformSchema.safeParse("invalid").success).toBe(false);
    });

    it("contextSchema validates contexts", () => {
      expect(contextSchema.safeParse("mvp").success).toBe(true);
      expect(contextSchema.safeParse("b2c").success).toBe(true);
      expect(contextSchema.safeParse("b2b").success).toBe(true);
      expect(contextSchema.safeParse("saas").success).toBe(true);
      expect(contextSchema.safeParse("api").success).toBe(true);
      expect(contextSchema.safeParse("internal").success).toBe(true);
      expect(contextSchema.safeParse("invalid").success).toBe(false);
    });

    it("modeSchema validates modes", () => {
      expect(modeSchema.safeParse("automated").success).toBe(true);
      expect(modeSchema.safeParse("guided").success).toBe(true);
      expect(modeSchema.safeParse("plan").success).toBe(true);
      expect(modeSchema.safeParse("invalid").success).toBe(false);
    });

    it("portSchema validates ports with default", () => {
      const result = portSchema.safeParse(undefined);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data).toBe(3000);
      }
    });

    it("portSchema validates port range", () => {
      expect(portSchema.safeParse(80).success).toBe(true);
      expect(portSchema.safeParse(3000).success).toBe(true);
      expect(portSchema.safeParse(65535).success).toBe(true);
      expect(portSchema.safeParse(0).success).toBe(false);
      expect(portSchema.safeParse(65536).success).toBe(false);
      expect(portSchema.safeParse(3.14).success).toBe(false);
    });
  });
});
