#!/usr/bin/env node
/**
 * Launch MCP Server - Token-Efficient Deployment Assistance
 *
 * Core tools always loaded, others deferred via search_tools.
 * Static content served via Resources (not tools).
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
  Tool,
} from "@modelcontextprotocol/sdk/types.js";
import { registerAnalysisTools, handleAnalysisTool } from "./tools/analyze.js";
import { registerRecommendationTools, handleRecommendationTool } from "./tools/recommend.js";
import { registerModeTools, handleModeTool } from "./tools/modes.js";
import { registerGenerationTools, handleGenerationTool } from "./tools/generate.js";
import { registerExecutionTools, handleExecutionTool } from "./tools/execute.js";
import { listResources, readResource } from "./resources/index.js";
import { VERSION } from "./utils/version.js";

const server = new Server(
  { name: "launch", version: VERSION },
  {
    capabilities: {
      tools: {},
      resources: {},
    },
  }
);

// Core tools - always loaded (~4 tools, ~400 tokens)
const coreTools: Tool[] = [
  ...registerAnalysisTools(),       // analyze
  ...registerRecommendationTools(), // recommend
  ...registerModeTools(),           // deploy
  {
    name: "search_tools",
    description: "Find additional Launch tools. Query: 'docker', 'vercel', 'generate', 'logs', etc.",
    inputSchema: {
      type: "object" as const,
      properties: {
        query: { type: "string", description: "Search query" },
      },
      required: ["query"],
    },
  },
];

// Deferred tools - only loaded via search_tools
const deferredTools: Tool[] = [
  ...registerGenerationTools(),
  ...registerExecutionTools(),
];

// All tools for search
const allTools = [...coreTools, ...deferredTools];

// Tool search index
const toolIndex: Record<string, string[]> = {
  docker: ["check_docker_status", "deploy_to_docker", "generate_dockerfile", "generate_docker_compose"],
  vercel: ["deploy_to_vercel", "generate_platform_config"],
  railway: ["deploy_to_railway", "generate_platform_config"],
  fly: ["deploy_to_fly", "generate_platform_config"],
  render: ["generate_platform_config"],
  generate: ["generate_dockerfile", "generate_docker_compose", "generate_platform_config"],
  config: ["generate_dockerfile", "generate_docker_compose", "generate_platform_config", "check_deployment_readiness"],
  tunnel: ["setup_cloudflare_tunnel"],
  cloudflare: ["setup_cloudflare_tunnel"],
  logs: ["get_deployment_logs"],
  status: ["get_deployment_status", "check_docker_status", "check_platform_cli"],
  stop: ["stop_deployment"],
  cli: ["check_platform_cli"],
  check: ["check_docker_status", "check_platform_cli", "check_deployment_readiness"],
  validate: ["check_deployment_readiness"],
  preview: ["preview_generated_files"],
};

// === TOOLS ===

server.setRequestHandler(ListToolsRequestSchema, async () => {
  return { tools: coreTools };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  // Handle search_tools
  if (name === "search_tools") {
    const { query } = args as { query: string };
    const q = query.toLowerCase();

    const matches = new Set<string>();
    for (const [keyword, tools] of Object.entries(toolIndex)) {
      if (keyword.includes(q) || q.includes(keyword)) {
        tools.forEach((t) => matches.add(t));
      }
    }

    const found = allTools.filter((t) => matches.has(t.name));
    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify(found.map((t) => ({ name: t.name, description: t.description }))),
        },
      ],
    };
  }

  // Try handlers
  const result =
    (await handleAnalysisTool(name, args)) ||
    (await handleRecommendationTool(name, args)) ||
    (await handleModeTool(name, args)) ||
    (await handleGenerationTool(name, args)) ||
    (await handleExecutionTool(name, args));

  if (result) return result;

  return {
    content: [{ type: "text" as const, text: JSON.stringify({ error: "unknown_tool" }) }],
  };
});

// === RESOURCES ===

server.setRequestHandler(ListResourcesRequestSchema, async () => {
  return { resources: listResources() };
});

server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
  const { uri } = request.params;
  const content = readResource(uri);

  if (!content) {
    throw new Error(`Resource not found: ${uri}`);
  }

  return {
    contents: [
      {
        uri,
        mimeType: "application/json",
        text: content,
      },
    ],
  };
});

// === START ===

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error) => {
  console.error("Server error:", error);
  process.exit(1);
});
