/**
 * MCP Resources - Static content for Launch
 *
 * Resources are app-controlled, cached, and don't consume tool-call tokens.
 * Use for: platform profiles, commercial contexts, mode details, tutorials.
 */

import { Resource } from "@modelcontextprotocol/sdk/types.js";

// Platform profiles - detailed static data
export const PLATFORMS: Record<string, object> = {
  vercel: {
    name: "Vercel",
    type: "serverless",
    best_for: ["nextjs", "react", "vue", "svelte", "static"],
    features: ["edge_network", "preview_deploys", "zero_config"],
    limits: { function_size: "50MB", timeout_free: "10s", timeout_pro: "60s" },
    pricing: { free: "hobby", pro: "$20/user/mo" },
    db_support: false,
  },
  railway: {
    name: "Railway",
    type: "paas",
    best_for: ["express", "fastapi", "django", "nestjs", "fullstack"],
    features: ["instant_db", "docker", "github_integration"],
    limits: { memory: "8GB", cpu: "8vCPU" },
    pricing: { free: "$5_credit/mo", pro: "usage_based" },
    db_support: true,
  },
  render: {
    name: "Render",
    type: "paas",
    best_for: ["express", "fastapi", "django", "flask", "rails"],
    features: ["free_ssl", "auto_deploy", "managed_db", "workers"],
    limits: { free_hours: 750 },
    pricing: { free: "750h/mo", pro: "$7/service/mo" },
    db_support: true,
  },
  fly: {
    name: "Fly.io",
    type: "edge",
    best_for: ["express", "fastapi", "go", "rust", "realtime"],
    features: ["global_edge", "persistent_volumes", "websockets", "gpu"],
    limits: { free_vms: 3 },
    pricing: { free: "3_shared_vms", pro: "usage_based" },
    db_support: true,
  },
  docker: {
    name: "Docker Self-Deploy",
    type: "self_hosted",
    best_for: ["any"],
    features: ["full_control", "no_limits", "cloudflare_tunnel"],
    limits: { none: true },
    pricing: { free: "your_infra" },
    db_support: true,
  },
};

// Commercial contexts
export const CONTEXTS: Record<string, object> = {
  mvp: {
    name: "MVP/Prototype",
    priorities: ["speed", "cost", "simplicity"],
    recommended: ["railway", "vercel"],
  },
  b2c: {
    name: "B2C Application",
    priorities: ["performance", "global", "ux"],
    recommended: ["vercel", "fly"],
  },
  b2b: {
    name: "B2B/Enterprise",
    priorities: ["reliability", "security", "compliance"],
    recommended: ["docker", "railway"],
  },
  saas: {
    name: "SaaS Product",
    priorities: ["scalability", "cost_efficiency", "monitoring"],
    recommended: ["railway", "fly"],
  },
  api: {
    name: "API Service",
    priorities: ["latency", "uptime"],
    recommended: ["fly", "railway"],
  },
  internal: {
    name: "Internal Tool",
    priorities: ["simplicity", "cost", "security"],
    recommended: ["docker", "railway"],
  },
};

// Deployment modes
export const MODES: Record<string, object> = {
  automated: {
    name: "Automated",
    description: "Fast deployment with sensible defaults",
    steps: ["analyze", "recommend", "generate", "execute", "verify"],
    user_input: "minimal",
  },
  guided: {
    name: "Guided",
    description: "Step-by-step with explanations",
    steps: ["analyze", "confirm", "recommend", "select", "generate", "review", "execute", "verify"],
    user_input: "each_step",
  },
  plan: {
    name: "Plan Only",
    description: "Analysis and planning, no execution",
    steps: ["analyze", "compare", "estimate", "document"],
    user_input: "none",
  },
};

/**
 * List all available resources
 */
export function listResources(): Resource[] {
  const resources: Resource[] = [];

  // Platform resources
  resources.push({
    uri: "launch://platforms",
    name: "All Platforms",
    description: "List of all deployment platforms",
    mimeType: "application/json",
  });

  for (const id of Object.keys(PLATFORMS)) {
    resources.push({
      uri: `launch://platforms/${id}`,
      name: PLATFORMS[id] && (PLATFORMS[id] as { name: string }).name,
      description: `${id} platform details`,
      mimeType: "application/json",
    });
  }

  // Context resources
  resources.push({
    uri: "launch://contexts",
    name: "All Contexts",
    description: "Commercial deployment contexts",
    mimeType: "application/json",
  });

  for (const id of Object.keys(CONTEXTS)) {
    resources.push({
      uri: `launch://contexts/${id}`,
      name: CONTEXTS[id] && (CONTEXTS[id] as { name: string }).name,
      description: `${id} context details`,
      mimeType: "application/json",
    });
  }

  // Mode resources
  resources.push({
    uri: "launch://modes",
    name: "All Modes",
    description: "Deployment modes",
    mimeType: "application/json",
  });

  for (const id of Object.keys(MODES)) {
    resources.push({
      uri: `launch://modes/${id}`,
      name: MODES[id] && (MODES[id] as { name: string }).name,
      description: `${id} mode details`,
      mimeType: "application/json",
    });
  }

  return resources;
}

/**
 * Read a resource by URI
 */
export function readResource(uri: string): string | null {
  const parts = uri.replace("launch://", "").split("/");
  const [category, id] = parts;

  switch (category) {
    case "platforms":
      if (!id) return JSON.stringify(Object.keys(PLATFORMS));
      return PLATFORMS[id] ? JSON.stringify(PLATFORMS[id]) : null;

    case "contexts":
      if (!id) return JSON.stringify(Object.keys(CONTEXTS));
      return CONTEXTS[id] ? JSON.stringify(CONTEXTS[id]) : null;

    case "modes":
      if (!id) return JSON.stringify(Object.keys(MODES));
      return MODES[id] ? JSON.stringify(MODES[id]) : null;

    default:
      return null;
  }
}
