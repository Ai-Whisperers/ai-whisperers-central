/**
 * MCP Resources tests
 */

import { describe, it, expect } from "vitest";
import {
  PLATFORMS,
  CONTEXTS,
  MODES,
  listResources,
  readResource,
} from "../src/resources/index.js";

describe("MCP Resources", () => {
  describe("PLATFORMS", () => {
    it("contains all supported platforms", () => {
      expect(Object.keys(PLATFORMS)).toEqual([
        "vercel",
        "railway",
        "render",
        "fly",
        "docker",
      ]);
    });

    it("each platform has required fields", () => {
      for (const [id, platform] of Object.entries(PLATFORMS)) {
        const p = platform as Record<string, unknown>;
        expect(p.name).toBeDefined();
        expect(p.type).toBeDefined();
        expect(p.best_for).toBeDefined();
        expect(p.features).toBeDefined();
        expect(p.pricing).toBeDefined();
        expect(p.db_support).toBeDefined();
      }
    });

    it("vercel is serverless without db support", () => {
      const vercel = PLATFORMS.vercel as Record<string, unknown>;
      expect(vercel.type).toBe("serverless");
      expect(vercel.db_support).toBe(false);
    });

    it("railway supports databases", () => {
      const railway = PLATFORMS.railway as Record<string, unknown>;
      expect(railway.db_support).toBe(true);
    });

    it("docker is self-hosted with full control", () => {
      const docker = PLATFORMS.docker as Record<string, unknown>;
      expect(docker.type).toBe("self_hosted");
      expect((docker.features as string[]).includes("full_control")).toBe(true);
    });
  });

  describe("CONTEXTS", () => {
    it("contains all commercial contexts", () => {
      expect(Object.keys(CONTEXTS)).toEqual([
        "mvp",
        "b2c",
        "b2b",
        "saas",
        "api",
        "internal",
      ]);
    });

    it("each context has required fields", () => {
      for (const [id, context] of Object.entries(CONTEXTS)) {
        const c = context as Record<string, unknown>;
        expect(c.name).toBeDefined();
        expect(c.priorities).toBeDefined();
        expect(c.recommended).toBeDefined();
      }
    });

    it("mvp prioritizes speed and cost", () => {
      const mvp = CONTEXTS.mvp as Record<string, unknown>;
      expect((mvp.priorities as string[]).includes("speed")).toBe(true);
      expect((mvp.priorities as string[]).includes("cost")).toBe(true);
    });

    it("b2b prioritizes security", () => {
      const b2b = CONTEXTS.b2b as Record<string, unknown>;
      expect((b2b.priorities as string[]).includes("security")).toBe(true);
    });
  });

  describe("MODES", () => {
    it("contains all deployment modes", () => {
      expect(Object.keys(MODES)).toEqual(["automated", "guided", "plan"]);
    });

    it("each mode has required fields", () => {
      for (const [id, mode] of Object.entries(MODES)) {
        const m = mode as Record<string, unknown>;
        expect(m.name).toBeDefined();
        expect(m.description).toBeDefined();
        expect(m.steps).toBeDefined();
        expect(m.user_input).toBeDefined();
      }
    });

    it("automated mode has minimal user input", () => {
      const automated = MODES.automated as Record<string, unknown>;
      expect(automated.user_input).toBe("minimal");
    });

    it("plan mode has no execution steps", () => {
      const plan = MODES.plan as Record<string, unknown>;
      expect((plan.steps as string[]).includes("execute")).toBe(false);
    });
  });

  describe("listResources()", () => {
    it("returns all resources", () => {
      const resources = listResources();
      expect(resources.length).toBeGreaterThan(0);
    });

    it("includes platform list resource", () => {
      const resources = listResources();
      const platformList = resources.find((r) => r.uri === "launch://platforms");
      expect(platformList).toBeDefined();
      expect(platformList?.name).toBe("All Platforms");
    });

    it("includes individual platform resources", () => {
      const resources = listResources();
      const vercel = resources.find((r) => r.uri === "launch://platforms/vercel");
      expect(vercel).toBeDefined();
    });

    it("includes context resources", () => {
      const resources = listResources();
      const contextList = resources.find((r) => r.uri === "launch://contexts");
      expect(contextList).toBeDefined();
    });

    it("includes mode resources", () => {
      const resources = listResources();
      const modeList = resources.find((r) => r.uri === "launch://modes");
      expect(modeList).toBeDefined();
    });

    it("all resources have required fields", () => {
      const resources = listResources();
      for (const resource of resources) {
        expect(resource.uri).toBeDefined();
        expect(resource.name).toBeDefined();
        expect(resource.mimeType).toBe("application/json");
      }
    });
  });

  describe("readResource()", () => {
    it("returns platform list", () => {
      const content = readResource("launch://platforms");
      expect(content).not.toBeNull();
      const parsed = JSON.parse(content!);
      expect(parsed).toEqual(["vercel", "railway", "render", "fly", "docker"]);
    });

    it("returns individual platform", () => {
      const content = readResource("launch://platforms/vercel");
      expect(content).not.toBeNull();
      const parsed = JSON.parse(content!);
      expect(parsed.name).toBe("Vercel");
    });

    it("returns context list", () => {
      const content = readResource("launch://contexts");
      expect(content).not.toBeNull();
      const parsed = JSON.parse(content!);
      expect(parsed).toContain("mvp");
    });

    it("returns individual context", () => {
      const content = readResource("launch://contexts/mvp");
      expect(content).not.toBeNull();
      const parsed = JSON.parse(content!);
      expect(parsed.name).toBe("MVP/Prototype");
    });

    it("returns mode list", () => {
      const content = readResource("launch://modes");
      expect(content).not.toBeNull();
      const parsed = JSON.parse(content!);
      expect(parsed).toContain("automated");
    });

    it("returns individual mode", () => {
      const content = readResource("launch://modes/guided");
      expect(content).not.toBeNull();
      const parsed = JSON.parse(content!);
      expect(parsed.name).toBe("Guided");
    });

    it("returns null for invalid category", () => {
      const content = readResource("launch://invalid");
      expect(content).toBeNull();
    });

    it("returns null for invalid platform", () => {
      const content = readResource("launch://platforms/invalid");
      expect(content).toBeNull();
    });
  });
});
