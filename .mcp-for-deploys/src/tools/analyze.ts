/**
 * Analysis Tools - Lean codebase analysis with validation
 */

import { existsSync, readdirSync, readFileSync, statSync } from "fs";
import { join, extname } from "path";
import { Tool, CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";
import { validate } from "../utils/validation.js";

type ToolResponse = CallToolResult;

// Input schema
const analyzeSchema = z.object({
  path: z.string().min(1, "Path required"),
});

// Detection maps
const LANG_EXT: Record<string, string> = {
  ".ts": "typescript", ".tsx": "typescript", ".js": "javascript", ".jsx": "javascript",
  ".py": "python", ".rb": "ruby", ".java": "java", ".go": "go", ".rs": "rust", ".php": "php",
};

const FRAMEWORKS: Record<string, string[]> = {
  nextjs: ["next"], react: ["react"], vue: ["vue"], angular: ["@angular/core"],
  svelte: ["svelte"], express: ["express"], fastify: ["fastify"], nestjs: ["@nestjs/core"],
};

const DB_PKGS = ["pg", "postgres", "mysql", "mysql2", "mongodb", "mongoose", "redis", "prisma", "typeorm", "sequelize"];

function detectLanguage(path: string): string {
  const counts: Record<string, number> = {};

  function scan(dir: string, depth = 0) {
    if (depth > 3) return;
    try {
      for (const entry of readdirSync(dir)) {
        if (entry.startsWith(".") || entry === "node_modules") continue;
        const full = join(dir, entry);
        try {
          const stat = statSync(full);
          if (stat.isDirectory()) scan(full, depth + 1);
          else {
            const lang = LANG_EXT[extname(entry)];
            if (lang) counts[lang] = (counts[lang] || 0) + 1;
          }
        } catch { continue; }
      }
    } catch { return; }
  }

  scan(path);
  const sorted = Object.entries(counts).sort((a, b) => b[1] - a[1]);
  return sorted[0]?.[0] || "unknown";
}

function detectFramework(path: string): string {
  const pkgPath = join(path, "package.json");
  if (existsSync(pkgPath)) {
    try {
      const pkg = JSON.parse(readFileSync(pkgPath, "utf-8"));
      const deps = { ...pkg.dependencies, ...pkg.devDependencies };
      for (const [fw, indicators] of Object.entries(FRAMEWORKS)) {
        if (indicators.some((i) => deps[i])) return fw;
      }
    } catch { /* continue */ }
  }

  const reqPath = join(path, "requirements.txt");
  if (existsSync(reqPath)) {
    try {
      const content = readFileSync(reqPath, "utf-8").toLowerCase();
      if (content.includes("fastapi")) return "fastapi";
      if (content.includes("django")) return "django";
      if (content.includes("flask")) return "flask";
    } catch { /* continue */ }
  }

  return "unknown";
}

function detectDatabase(path: string): boolean {
  const pkgPath = join(path, "package.json");
  if (existsSync(pkgPath)) {
    try {
      const pkg = JSON.parse(readFileSync(pkgPath, "utf-8"));
      const deps = { ...pkg.dependencies, ...pkg.devDependencies };
      if (DB_PKGS.some((d) => deps[d])) return true;
    } catch { /* continue */ }
  }
  return false;
}

function detectComplexity(path: string): number {
  let score = 1;
  if (["lerna.json", "nx.json", "turbo.json"].some((f) => existsSync(join(path, f)))) score += 1;
  if (existsSync(join(path, "Dockerfile")) || existsSync(join(path, "docker-compose.yml"))) score += 0.5;
  if (existsSync(join(path, ".github", "workflows")) || existsSync(join(path, ".gitlab-ci.yml"))) score += 0.5;
  if (detectDatabase(path)) score += 1;
  return Math.min(5, Math.round(score));
}

export function registerAnalysisTools(): Tool[] {
  return [
    {
      name: "analyze",
      description: "Analyze project. Returns: {lang, framework, db, complexity}",
      inputSchema: {
        type: "object" as const,
        properties: {
          path: { type: "string", description: "Project path" },
        },
        required: ["path"],
      },
    },
  ];
}

export async function handleAnalysisTool(
  name: string,
  args: unknown
): Promise<ToolResponse | null> {
  if (name !== "analyze") return null;

  // Validate input
  const validation = validate(analyzeSchema, args);
  if (!validation.success) {
    return {
      content: [{ type: "text" as const, text: JSON.stringify(validation.error) }],
    };
  }

  const { path } = validation.data;

  // Check path exists
  if (!existsSync(path)) {
    return {
      content: [{ type: "text" as const, text: JSON.stringify({ error: { code: "NOT_FOUND", message: "Path not found" } }) }],
    };
  }

  // Return compact analysis
  return {
    content: [
      {
        type: "text" as const,
        text: JSON.stringify({
          lang: detectLanguage(path),
          framework: detectFramework(path),
          db: detectDatabase(path),
          complexity: detectComplexity(path),
        }),
      },
    ],
  };
}
