/**
 * Deployment Mode Tools - Lean mode management with validation
 */

import { Tool, CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";
import { validate } from "../utils/validation.js";
import { existsSync } from "fs";

type ToolResponse = CallToolResult;

// Input schema
const deploySchema = z.object({
  path: z.string().min(1, "Path required"),
  mode: z.enum(["automated", "guided", "plan"]),
  context: z.enum(["mvp", "b2c", "b2b", "saas", "api", "internal"]).optional(),
  platform: z.enum(["vercel", "railway", "render", "fly", "docker"]).optional(),
});

const WORKFLOWS: Record<string, string[]> = {
  automated: ["analyze", "recommend", "generate", "execute", "verify"],
  guided: ["analyze", "confirm", "recommend", "select", "generate", "review", "execute", "verify"],
  plan: ["analyze", "compare", "estimate", "document"],
};

export function registerModeTools(): Tool[] {
  return [
    {
      name: "deploy",
      description: "Start deployment. Mode: automated|guided|plan. Returns workflow state.",
      inputSchema: {
        type: "object" as const,
        properties: {
          path: { type: "string", description: "Project path" },
          mode: { type: "string", enum: ["automated", "guided", "plan"] },
          context: { type: "string", enum: ["mvp", "b2c", "b2b", "saas", "api", "internal"] },
          platform: { type: "string", enum: ["vercel", "railway", "render", "fly", "docker"] },
        },
        required: ["path", "mode"],
      },
    },
  ];
}

export async function handleModeTool(
  name: string,
  args: unknown
): Promise<ToolResponse | null> {
  if (name !== "deploy") return null;

  const validation = validate(deploySchema, args);
  if (!validation.success) {
    return {
      content: [{ type: "text" as const, text: JSON.stringify(validation.error) }],
    };
  }

  const { path, mode, context, platform } = validation.data;

  // Validate path exists
  if (!existsSync(path)) {
    return {
      content: [{ type: "text" as const, text: JSON.stringify({ error: { code: "NOT_FOUND", message: "Path not found" } }) }],
    };
  }

  return {
    content: [
      {
        type: "text" as const,
        text: JSON.stringify({
          mode,
          path,
          context: context || "mvp",
          platform: platform || null,
          workflow: WORKFLOWS[mode],
        }),
      },
    ],
  };
}
