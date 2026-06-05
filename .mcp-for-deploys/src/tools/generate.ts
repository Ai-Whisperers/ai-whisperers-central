/**
 * Config Generation Tools - Generate deployment configurations
 *
 * Generates Dockerfiles, docker-compose, and platform-specific configs.
 */

import { Tool, CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import { existsSync, readFileSync } from "fs";
import { join } from "path";

type ToolResponse = CallToolResult;

// Dockerfile templates by framework
const DOCKERFILE_TEMPLATES: Record<string, string> = {
  nextjs: `# syntax=docker/dockerfile:1
FROM node:20-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

COPY package.json package-lock.json* yarn.lock* pnpm-lock.yaml* ./
RUN \\
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \\
  elif [ -f package-lock.json ]; then npm ci; \\
  elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm i --frozen-lockfile; \\
  else echo "Lockfile not found." && exit 1; \\
  fi

# Build the application
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

# Production image
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
`,

  react: `# syntax=docker/dockerfile:1
FROM node:20-alpine AS build

WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine AS production
COPY --from=build /app/dist /usr/share/nginx/html
COPY --from=build /app/build /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
`,

  express: `# syntax=docker/dockerfile:1
FROM node:20-alpine

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 expressjs

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY --chown=expressjs:nodejs . .

USER expressjs

EXPOSE 3000
ENV NODE_ENV=production

CMD ["node", "index.js"]
`,

  fastapi: `# syntax=docker/dockerfile:1
FROM python:3.12-slim

WORKDIR /app

RUN adduser --system --uid 1001 appuser

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY --chown=appuser:appuser . .

USER appuser

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
`,

  django: `# syntax=docker/dockerfile:1
FROM python:3.12-slim

WORKDIR /app

RUN adduser --system --uid 1001 appuser

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY --chown=appuser:appuser . .

RUN python manage.py collectstatic --noinput

USER appuser

EXPOSE 8000

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "config.wsgi:application"]
`,

  default: `# syntax=docker/dockerfile:1
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 3000

CMD ["npm", "start"]
`,
};

// Docker Compose template
function generateDockerCompose(
  serviceName: string,
  port: number,
  hasDatabase: boolean,
  databases: string[]
): string {
  let compose = `version: '3.8'

services:
  ${serviceName}:
    build: .
    ports:
      - "\${PORT:-${port}}:${port}"
    environment:
      - NODE_ENV=production
`;

  if (hasDatabase) {
    compose += `    depends_on:\n`;
    if (databases.some((d) => ["postgres", "pg", "postgresql"].includes(d))) {
      compose += `      - postgres\n`;
    }
    if (databases.some((d) => ["redis", "ioredis"].includes(d))) {
      compose += `      - redis\n`;
    }
    if (databases.some((d) => ["mongodb", "mongoose"].includes(d))) {
      compose += `      - mongo\n`;
    }
  }

  compose += `    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:${port}/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
`;

  // Add database services
  if (databases.some((d) => ["postgres", "pg", "postgresql"].includes(d))) {
    compose += `
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: \${POSTGRES_USER:-app}
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD:-changeme}
      POSTGRES_DB: \${POSTGRES_DB:-app}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped
`;
  }

  if (databases.some((d) => ["redis", "ioredis"].includes(d))) {
    compose += `
  redis:
    image: redis:7-alpine
    restart: unless-stopped
`;
  }

  if (databases.some((d) => ["mongodb", "mongoose"].includes(d))) {
    compose += `
  mongo:
    image: mongo:7
    environment:
      MONGO_INITDB_ROOT_USERNAME: \${MONGO_USER:-app}
      MONGO_INITDB_ROOT_PASSWORD: \${MONGO_PASSWORD:-changeme}
    volumes:
      - mongo_data:/data/db
    restart: unless-stopped
`;
  }

  // Add volumes if databases present
  if (hasDatabase) {
    compose += `
volumes:`;
    if (databases.some((d) => ["postgres", "pg", "postgresql"].includes(d))) {
      compose += `
  postgres_data:`;
    }
    if (databases.some((d) => ["mongodb", "mongoose"].includes(d))) {
      compose += `
  mongo_data:`;
    }
  }

  return compose;
}

// Platform config generators
function generateVercelConfig(framework: string): object {
  const config: Record<string, unknown> = {
    $schema: "https://openapi.vercel.sh/vercel.json",
  };

  if (framework === "nextjs") {
    config.framework = "nextjs";
  } else if (["react", "vue", "svelte"].includes(framework)) {
    config.framework = framework;
    config.buildCommand = "npm run build";
    config.outputDirectory = "dist";
  }

  return config;
}

function generateRailwayConfig(serviceName: string, port: number): string {
  return `[build]
builder = "dockerfile"

[deploy]
healthcheckPath = "/health"
healthcheckTimeout = 100
restartPolicyType = "on_failure"
restartPolicyMaxRetries = 3

[service]
name = "${serviceName}"
internalPort = ${port}
`;
}

function generateRenderConfig(
  serviceName: string,
  framework: string,
  hasDatabase: boolean
): object {
  const services: Array<Record<string, unknown>> = [
    {
      type: "web",
      name: serviceName,
      runtime: framework.includes("python") ? "python" : "node",
      buildCommand:
        framework === "nextjs" ? "npm install && npm run build" : "npm install",
      startCommand: framework === "nextjs" ? "npm start" : "node index.js",
      healthCheckPath: "/health",
      envVars: [
        {
          key: "NODE_ENV",
          value: "production",
        },
      ],
    },
  ];

  if (hasDatabase) {
    services.push({
      type: "pserv",
      name: `${serviceName}-db`,
      plan: "starter",
      ipAllowList: [],
    });
  }

  return { services };
}

function generateFlyConfig(serviceName: string, port: number): string {
  return `app = "${serviceName}"
primary_region = "iad"

[build]

[http_service]
  internal_port = ${port}
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 0
  processes = ["app"]

[[vm]]
  memory = "256mb"
  cpu_kind = "shared"
  cpus = 1

[checks]
  [checks.health]
    grace_period = "30s"
    interval = "15s"
    method = "get"
    path = "/health"
    port = ${port}
    timeout = "10s"
    type = "http"
`;
}

/**
 * Detect entry point for the application
 */
function detectEntryPoint(projectPath: string, framework: string): string {
  const possibleEntries = [
    "index.js",
    "server.js",
    "app.js",
    "main.js",
    "src/index.js",
    "src/server.js",
    "dist/index.js",
    "main.py",
    "app.py",
    "manage.py",
  ];

  for (const entry of possibleEntries) {
    if (existsSync(join(projectPath, entry))) {
      return entry;
    }
  }

  // Check package.json for main
  const pkgPath = join(projectPath, "package.json");
  if (existsSync(pkgPath)) {
    try {
      const pkg = JSON.parse(readFileSync(pkgPath, "utf-8"));
      if (pkg.main) return pkg.main;
    } catch {
      // Continue
    }
  }

  return framework.includes("python") ? "main.py" : "index.js";
}

/**
 * Register generation tools
 */
export function registerGenerationTools(): Tool[] {
  return [
    {
      name: "generate_dockerfile",
      description:
        "Generate an optimized Dockerfile for the project with multi-stage builds and security best practices",
      inputSchema: {
        type: "object" as const,
        properties: {
          path: {
            type: "string",
            description: "Path to the project directory",
          },
          framework: {
            type: "string",
            description:
              "Framework (nextjs, react, express, fastapi, django, etc.)",
          },
          port: {
            type: "number",
            description: "Port to expose (default: 3000)",
          },
        },
        required: ["path", "framework"],
      },
    },
    {
      name: "generate_docker_compose",
      description:
        "Generate a docker-compose.yml with the app service and any required databases",
      inputSchema: {
        type: "object" as const,
        properties: {
          path: {
            type: "string",
            description: "Path to the project directory",
          },
          service_name: {
            type: "string",
            description: "Name for the service (default: app)",
          },
          port: {
            type: "number",
            description: "Port to expose (default: 3000)",
          },
          databases: {
            type: "array",
            items: { type: "string" },
            description: "Database services to include (postgres, redis, mongo)",
          },
        },
        required: ["path"],
      },
    },
    {
      name: "generate_platform_config",
      description:
        "Generate platform-specific configuration file (vercel.json, railway.toml, render.yaml, fly.toml)",
      inputSchema: {
        type: "object" as const,
        properties: {
          platform: {
            type: "string",
            enum: ["vercel", "railway", "render", "fly"],
            description: "Target platform",
          },
          framework: {
            type: "string",
            description: "Project framework",
          },
          service_name: {
            type: "string",
            description: "Service name",
          },
          port: {
            type: "number",
            description: "Internal port (default: 3000)",
          },
          has_database: {
            type: "boolean",
            description: "Whether the project uses a database",
          },
        },
        required: ["platform", "framework"],
      },
    },
    {
      name: "preview_generated_files",
      description:
        "Preview all files that would be generated for deployment without writing them",
      inputSchema: {
        type: "object" as const,
        properties: {
          path: {
            type: "string",
            description: "Path to the project directory",
          },
          platform: {
            type: "string",
            enum: ["docker", "vercel", "railway", "render", "fly"],
            description: "Target platform",
          },
          framework: {
            type: "string",
            description: "Project framework",
          },
        },
        required: ["path", "platform", "framework"],
      },
    },
    {
      name: "check_deployment_readiness",
      description:
        "Check if a project is ready for deployment and identify missing requirements",
      inputSchema: {
        type: "object" as const,
        properties: {
          path: {
            type: "string",
            description: "Path to the project directory",
          },
          platform: {
            type: "string",
            enum: ["docker", "vercel", "railway", "render", "fly"],
            description: "Target platform",
          },
        },
        required: ["path", "platform"],
      },
    },
  ];
}

/**
 * Handle generation tool calls
 */
export async function handleGenerationTool(
  name: string,
  args: unknown
): Promise<ToolResponse | null> {
  switch (name) {
    case "generate_dockerfile": {
      const params = args as {
        path: string;
        framework: string;
        port?: number;
      };
      const port = params.port || 3000;

      let template =
        DOCKERFILE_TEMPLATES[params.framework] || DOCKERFILE_TEMPLATES.default;

      // Customize entry point
      const entryPoint = detectEntryPoint(params.path, params.framework);
      template = template.replace(/index\.js/g, entryPoint);
      template = template.replace(/EXPOSE \d+/g, `EXPOSE ${port}`);

      return {
        content: [
          {
            type: "text" as const,
            text: JSON.stringify(
              {
                filename: "Dockerfile",
                content: template,
                framework: params.framework,
                port,
                instructions:
                  "Save this as 'Dockerfile' in your project root. Build with: docker build -t myapp .",
              },
              null,
              2
            ),
          },
        ],
      };
    }

    case "generate_docker_compose": {
      const params = args as {
        path: string;
        service_name?: string;
        port?: number;
        databases?: string[];
      };

      const serviceName = params.service_name || "app";
      const port = params.port || 3000;
      const databases = params.databases || [];
      const hasDatabase = databases.length > 0;

      const compose = generateDockerCompose(
        serviceName,
        port,
        hasDatabase,
        databases
      );

      return {
        content: [
          {
            type: "text" as const,
            text: JSON.stringify(
              {
                filename: "docker-compose.yml",
                content: compose,
                services: [serviceName, ...databases],
                instructions:
                  "Save as 'docker-compose.yml'. Run with: docker-compose up -d",
              },
              null,
              2
            ),
          },
        ],
      };
    }

    case "generate_platform_config": {
      const params = args as {
        platform: string;
        framework: string;
        service_name?: string;
        port?: number;
        has_database?: boolean;
      };

      const serviceName = params.service_name || "app";
      const port = params.port || 3000;
      const hasDatabase = params.has_database || false;

      let config: string | object;
      let filename: string;

      switch (params.platform) {
        case "vercel":
          config = generateVercelConfig(params.framework);
          filename = "vercel.json";
          break;
        case "railway":
          config = generateRailwayConfig(serviceName, port);
          filename = "railway.toml";
          break;
        case "render":
          config = generateRenderConfig(serviceName, params.framework, hasDatabase);
          filename = "render.yaml";
          break;
        case "fly":
          config = generateFlyConfig(serviceName, port);
          filename = "fly.toml";
          break;
        default:
          return {
            content: [
              {
                type: "text" as const,
                text: JSON.stringify({ error: `Unknown platform: ${params.platform}` }),
              },
            ],
          };
      }

      return {
        content: [
          {
            type: "text" as const,
            text: JSON.stringify(
              {
                filename,
                content: typeof config === "string" ? config : JSON.stringify(config, null, 2),
                platform: params.platform,
                instructions: `Save as '${filename}' in your project root.`,
              },
              null,
              2
            ),
          },
        ],
      };
    }

    case "preview_generated_files": {
      const params = args as {
        path: string;
        platform: string;
        framework: string;
      };

      const files: Array<{ filename: string; preview: string }> = [];

      if (params.platform === "docker" || params.platform === "railway" || params.platform === "fly") {
        const template =
          DOCKERFILE_TEMPLATES[params.framework] || DOCKERFILE_TEMPLATES.default;
        files.push({
          filename: "Dockerfile",
          preview: template.substring(0, 500) + "...",
        });
      }

      if (params.platform === "docker") {
        files.push({
          filename: "docker-compose.yml",
          preview: generateDockerCompose("app", 3000, false, []).substring(0, 300) + "...",
        });
      }

      if (params.platform === "vercel") {
        files.push({
          filename: "vercel.json",
          preview: JSON.stringify(generateVercelConfig(params.framework), null, 2),
        });
      }

      if (params.platform === "railway") {
        files.push({
          filename: "railway.toml",
          preview: generateRailwayConfig("app", 3000),
        });
      }

      if (params.platform === "render") {
        files.push({
          filename: "render.yaml",
          preview: JSON.stringify(generateRenderConfig("app", params.framework, false), null, 2),
        });
      }

      if (params.platform === "fly") {
        files.push({
          filename: "fly.toml",
          preview: generateFlyConfig("app", 3000),
        });
      }

      return {
        content: [
          {
            type: "text" as const,
            text: JSON.stringify(
              {
                platform: params.platform,
                files,
                note: "These are previews. Use specific generate_* tools to get full content.",
              },
              null,
              2
            ),
          },
        ],
      };
    }

    case "check_deployment_readiness": {
      const params = args as { path: string; platform: string };
      const issues: string[] = [];
      const ready: string[] = [];

      // Check for package.json or requirements.txt
      if (existsSync(join(params.path, "package.json"))) {
        ready.push("package.json found");

        const pkg = JSON.parse(
          readFileSync(join(params.path, "package.json"), "utf-8")
        );
        if (!pkg.scripts?.start && !pkg.scripts?.build) {
          issues.push("Missing 'start' or 'build' script in package.json");
        } else {
          ready.push("Build/start scripts defined");
        }
      } else if (existsSync(join(params.path, "requirements.txt"))) {
        ready.push("requirements.txt found");
      } else {
        issues.push("No package.json or requirements.txt found");
      }

      // Check for existing configs
      if (existsSync(join(params.path, "Dockerfile"))) {
        ready.push("Dockerfile exists");
      } else if (["docker", "railway", "fly"].includes(params.platform)) {
        issues.push("Dockerfile not found (required for this platform)");
      }

      // Check for .env.example
      if (existsSync(join(params.path, ".env.example"))) {
        ready.push(".env.example found for environment reference");
      }

      // Check for .gitignore
      if (!existsSync(join(params.path, ".gitignore"))) {
        issues.push("No .gitignore file (recommended)");
      }

      return {
        content: [
          {
            type: "text" as const,
            text: JSON.stringify(
              {
                platform: params.platform,
                ready_for_deployment: issues.length === 0,
                checks_passed: ready,
                issues,
                recommendation:
                  issues.length === 0
                    ? "Project is ready for deployment"
                    : "Address the issues above before deploying",
              },
              null,
              2
            ),
          },
        ],
      };
    }

    default:
      return null;
  }
}
