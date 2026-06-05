/**
 * Core tools tests
 */

import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { registerAnalysisTools, handleAnalysisTool } from "../src/tools/analyze.js";
import { registerRecommendationTools, handleRecommendationTool } from "../src/tools/recommend.js";
import { registerModeTools, handleModeTool } from "../src/tools/modes.js";
import * as fs from "fs";
import * as path from "path";
import { tmpdir } from "os";

describe("Analysis Tools", () => {
  describe("registerAnalysisTools()", () => {
    it("registers analyze tool", () => {
      const tools = registerAnalysisTools();
      expect(tools.length).toBe(1);
      expect(tools[0].name).toBe("analyze");
    });

    it("has correct input schema", () => {
      const tools = registerAnalysisTools();
      const schema = tools[0].inputSchema;
      expect(schema.type).toBe("object");
      expect(schema.required).toContain("path");
    });
  });

  describe("handleAnalysisTool()", () => {
    let testDir: string;

    beforeEach(() => {
      testDir = path.join(tmpdir(), `launch-test-${Date.now()}`);
      fs.mkdirSync(testDir, { recursive: true });
    });

    afterEach(() => {
      fs.rmSync(testDir, { recursive: true, force: true });
    });

    it("returns null for non-analyze tool", async () => {
      const result = await handleAnalysisTool("other", {});
      expect(result).toBeNull();
    });

    it("returns validation error for missing path", async () => {
      const result = await handleAnalysisTool("analyze", {});
      expect(result).not.toBeNull();
      const content = JSON.parse(result!.content[0].text as string);
      expect(content.error.code).toBe("VALIDATION_ERROR");
    });

    it("returns not found for invalid path", async () => {
      const result = await handleAnalysisTool("analyze", { path: "/nonexistent/path" });
      expect(result).not.toBeNull();
      const content = JSON.parse(result!.content[0].text as string);
      expect(content.error.code).toBe("NOT_FOUND");
    });

    it("analyzes empty directory", async () => {
      const result = await handleAnalysisTool("analyze", { path: testDir });
      expect(result).not.toBeNull();
      const content = JSON.parse(result!.content[0].text as string);
      expect(content.lang).toBe("unknown");
      expect(content.framework).toBe("unknown");
      expect(content.db).toBe(false);
      expect(content.complexity).toBeGreaterThanOrEqual(1);
    });

    it("detects TypeScript project", async () => {
      fs.writeFileSync(path.join(testDir, "index.ts"), "console.log('hello');");
      fs.writeFileSync(path.join(testDir, "utils.ts"), "export const foo = 1;");

      const result = await handleAnalysisTool("analyze", { path: testDir });
      const content = JSON.parse(result!.content[0].text as string);
      expect(content.lang).toBe("typescript");
    });

    it("detects Next.js framework", async () => {
      const pkg = { dependencies: { next: "14.0.0", react: "18.0.0" } };
      fs.writeFileSync(path.join(testDir, "package.json"), JSON.stringify(pkg));

      const result = await handleAnalysisTool("analyze", { path: testDir });
      const content = JSON.parse(result!.content[0].text as string);
      expect(content.framework).toBe("nextjs");
    });

    it("detects database usage", async () => {
      const pkg = { dependencies: { prisma: "5.0.0" } };
      fs.writeFileSync(path.join(testDir, "package.json"), JSON.stringify(pkg));

      const result = await handleAnalysisTool("analyze", { path: testDir });
      const content = JSON.parse(result!.content[0].text as string);
      expect(content.db).toBe(true);
    });

    it("detects complexity from Docker", async () => {
      fs.writeFileSync(path.join(testDir, "Dockerfile"), "FROM node:18");

      const result = await handleAnalysisTool("analyze", { path: testDir });
      const content = JSON.parse(result!.content[0].text as string);
      expect(content.complexity).toBeGreaterThanOrEqual(1);
    });
  });
});

describe("Recommendation Tools", () => {
  describe("registerRecommendationTools()", () => {
    it("registers recommend tool", () => {
      const tools = registerRecommendationTools();
      expect(tools.length).toBe(1);
      expect(tools[0].name).toBe("recommend");
    });

    it("has correct input schema", () => {
      const tools = registerRecommendationTools();
      const schema = tools[0].inputSchema;
      expect(schema.required).toContain("framework");
      expect(schema.required).toContain("context");
    });
  });

  describe("handleRecommendationTool()", () => {
    it("returns null for non-recommend tool", async () => {
      const result = await handleRecommendationTool("other", {});
      expect(result).toBeNull();
    });

    it("returns validation error for missing framework", async () => {
      const result = await handleRecommendationTool("recommend", { context: "mvp" });
      expect(result).not.toBeNull();
      const content = JSON.parse(result!.content[0].text as string);
      expect(content.error).toBeDefined();
    });

    it("returns ranked platforms for Next.js", async () => {
      const result = await handleRecommendationTool("recommend", {
        framework: "nextjs",
        context: "mvp",
      });
      expect(result).not.toBeNull();
      const content = JSON.parse(result!.content[0].text as string);
      expect(Array.isArray(content)).toBe(true);
      expect(content.length).toBe(5);
      expect(content[0].platform).toBeDefined();
      expect(content[0].score).toBeDefined();
    });

    it("scores Vercel highest for Next.js B2C", async () => {
      const result = await handleRecommendationTool("recommend", {
        framework: "nextjs",
        context: "b2c",
      });
      const content = JSON.parse(result!.content[0].text as string);
      expect(content[0].platform).toBe("vercel");
    });

    it("considers database requirement", async () => {
      const result = await handleRecommendationTool("recommend", {
        framework: "express",
        context: "saas",
        has_database: true,
      });
      const content = JSON.parse(result!.content[0].text as string);
      // Platforms with db support should score higher
      const vercelScore = content.find((p: { platform: string }) => p.platform === "vercel").score;
      const railwayScore = content.find((p: { platform: string }) => p.platform === "railway").score;
      expect(railwayScore).toBeGreaterThan(vercelScore);
    });

    it("considers complexity", async () => {
      const result = await handleRecommendationTool("recommend", {
        framework: "express",
        context: "b2b",
        complexity: 5,
      });
      const content = JSON.parse(result!.content[0].text as string);
      // High complexity should favor docker/fly
      expect(content[0].platform).toMatch(/docker|fly/);
    });

    it("returns sorted by score descending", async () => {
      const result = await handleRecommendationTool("recommend", {
        framework: "react",
        context: "mvp",
      });
      const content = JSON.parse(result!.content[0].text as string);
      for (let i = 1; i < content.length; i++) {
        expect(content[i - 1].score).toBeGreaterThanOrEqual(content[i].score);
      }
    });
  });
});

describe("Mode Tools", () => {
  describe("registerModeTools()", () => {
    it("registers deploy tool", () => {
      const tools = registerModeTools();
      expect(tools.length).toBe(1);
      expect(tools[0].name).toBe("deploy");
    });

    it("has correct input schema", () => {
      const tools = registerModeTools();
      const schema = tools[0].inputSchema;
      expect(schema.required).toContain("path");
      expect(schema.required).toContain("mode");
    });
  });

  describe("handleModeTool()", () => {
    let testDir: string;

    beforeEach(() => {
      testDir = path.join(tmpdir(), `launch-test-${Date.now()}`);
      fs.mkdirSync(testDir, { recursive: true });
    });

    afterEach(() => {
      fs.rmSync(testDir, { recursive: true, force: true });
    });

    it("returns null for non-deploy tool", async () => {
      const result = await handleModeTool("other", {});
      expect(result).toBeNull();
    });

    it("returns validation error for missing mode", async () => {
      const result = await handleModeTool("deploy", { path: testDir });
      expect(result).not.toBeNull();
      const content = JSON.parse(result!.content[0].text as string);
      expect(content.error).toBeDefined();
    });

    it("returns validation error for invalid mode", async () => {
      const result = await handleModeTool("deploy", { path: testDir, mode: "invalid" });
      const content = JSON.parse(result!.content[0].text as string);
      expect(content.error).toBeDefined();
    });

    it("returns not found for invalid path", async () => {
      const result = await handleModeTool("deploy", {
        path: "/nonexistent/path",
        mode: "automated",
      });
      const content = JSON.parse(result!.content[0].text as string);
      expect(content.error.code).toBe("NOT_FOUND");
    });

    it("returns workflow for automated mode", async () => {
      const result = await handleModeTool("deploy", {
        path: testDir,
        mode: "automated",
      });
      const content = JSON.parse(result!.content[0].text as string);
      expect(content.mode).toBe("automated");
      expect(content.path).toBe(testDir);
      expect(content.workflow).toContain("analyze");
      expect(content.workflow).toContain("execute");
    });

    it("returns workflow for guided mode", async () => {
      const result = await handleModeTool("deploy", {
        path: testDir,
        mode: "guided",
      });
      const content = JSON.parse(result!.content[0].text as string);
      expect(content.mode).toBe("guided");
      expect(content.workflow).toContain("confirm");
      expect(content.workflow).toContain("review");
    });

    it("returns workflow for plan mode", async () => {
      const result = await handleModeTool("deploy", {
        path: testDir,
        mode: "plan",
      });
      const content = JSON.parse(result!.content[0].text as string);
      expect(content.mode).toBe("plan");
      expect(content.workflow).toContain("document");
      expect(content.workflow).not.toContain("execute");
    });

    it("accepts optional context", async () => {
      const result = await handleModeTool("deploy", {
        path: testDir,
        mode: "automated",
        context: "saas",
      });
      const content = JSON.parse(result!.content[0].text as string);
      expect(content.context).toBe("saas");
    });

    it("accepts optional platform", async () => {
      const result = await handleModeTool("deploy", {
        path: testDir,
        mode: "automated",
        platform: "railway",
      });
      const content = JSON.parse(result!.content[0].text as string);
      expect(content.platform).toBe("railway");
    });

    it("defaults context to mvp", async () => {
      const result = await handleModeTool("deploy", {
        path: testDir,
        mode: "automated",
      });
      const content = JSON.parse(result!.content[0].text as string);
      expect(content.context).toBe("mvp");
    });
  });
});
