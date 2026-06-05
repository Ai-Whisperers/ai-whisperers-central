/**
 * Recommendation Tools - Lean platform recommendations with validation
 */

import { Tool, CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";
import { validate } from "../utils/validation.js";

type ToolResponse = CallToolResult;

// Input schema
const recommendSchema = z.object({
  framework: z.string().min(1, "Framework required"),
  has_database: z.boolean().default(false),
  complexity: z.number().int().min(1).max(5).default(2),
  context: z.enum(["mvp", "b2c", "b2b", "saas", "api", "internal"]),
});

// Platform scoring data
const PLATFORMS = {
  vercel: { best: ["nextjs", "react", "vue", "static"], db: false, maxComplexity: 3 },
  railway: { best: ["express", "fastapi", "django", "nestjs"], db: true, maxComplexity: 4 },
  render: { best: ["express", "fastapi", "django", "flask"], db: true, maxComplexity: 4 },
  fly: { best: ["express", "fastapi", "go", "rust"], db: true, maxComplexity: 5 },
  docker: { best: ["any"], db: true, maxComplexity: 5 },
};

const CONTEXT_BONUS: Record<string, Record<string, number>> = {
  mvp: { railway: 10, vercel: 5 },
  b2c: { vercel: 15, fly: 10 },
  b2b: { docker: 10, railway: 5 },
  saas: { railway: 10, fly: 10 },
  api: { fly: 10, railway: 5 },
  internal: { docker: 15, railway: 5 },
};

function score(
  platform: keyof typeof PLATFORMS,
  framework: string,
  hasDb: boolean,
  complexity: number,
  context: string
): number {
  const p = PLATFORMS[platform];
  let s = 50;
  if (p.best.includes(framework) || p.best.includes("any")) s += 20;
  if (hasDb) s += p.db ? 15 : -20;
  if (complexity <= p.maxComplexity) s += 10; else s -= 15;
  s += CONTEXT_BONUS[context]?.[platform] || 0;
  return Math.max(0, Math.min(100, s));
}

export function registerRecommendationTools(): Tool[] {
  return [
    {
      name: "recommend",
      description: "Get ranked platform recommendations. Returns: [{platform, score}]",
      inputSchema: {
        type: "object" as const,
        properties: {
          framework: { type: "string", description: "Detected framework" },
          has_database: { type: "boolean", description: "Uses database" },
          complexity: { type: "number", description: "Complexity 1-5" },
          context: {
            type: "string",
            enum: ["mvp", "b2c", "b2b", "saas", "api", "internal"],
          },
        },
        required: ["framework", "context"],
      },
    },
  ];
}

export async function handleRecommendationTool(
  name: string,
  args: unknown
): Promise<ToolResponse | null> {
  if (name !== "recommend") return null;

  const validation = validate(recommendSchema, args);
  if (!validation.success) {
    return {
      content: [{ type: "text" as const, text: JSON.stringify(validation.error) }],
    };
  }

  const { framework, has_database = false, complexity = 2, context } = validation.data;

  const ranked = Object.keys(PLATFORMS)
    .map((p) => ({
      platform: p,
      score: score(p as keyof typeof PLATFORMS, framework, has_database, complexity, context),
    }))
    .sort((a, b) => b.score - a.score);

  return {
    content: [{ type: "text" as const, text: JSON.stringify(ranked) }],
  };
}
