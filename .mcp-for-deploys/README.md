# Launch MCP

[![Node.js](https://img.shields.io/badge/node-%3E%3D18.0.0-brightgreen)](https://nodejs.org/)
[![TypeScript](https://img.shields.io/badge/typescript-5.7-blue)](https://www.typescriptlang.org/)
[![MCP SDK](https://img.shields.io/badge/MCP%20SDK-1.0.0-purple)](https://modelcontextprotocol.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

MCP server for intelligent deployment assistance. Analyze projects, get platform recommendations, and deploy applications through Claude.

[![GitHub](https://img.shields.io/badge/GitHub-Ai--Whisperers%2Fmcp--for--deploys-181717?logo=github)](https://github.com/Ai-Whisperers/mcp-for-deploys)

---

## Quick Start

### Install

```bash
# Clone and build
git clone https://github.com/Ai-Whisperers/mcp-for-deploys.git
cd mcp-for-deploys
npm install && npm run build

# Register with Claude Code
npm run cli install
```

### Verify

```bash
npm run cli doctor
```

### Usage

Ask Claude to deploy your project:

```
"Deploy my project at ./my-app using guided mode"
"Analyze ./api-service and recommend a platform"
"Generate a Dockerfile for my Express app"
```

---

## Deployment Strategy

> **For rapid product rotation, Launch prioritizes two paths: Vercel and Self-Deploy (Docker).**

| Path | Best For | Speed | Control |
|:-----|:---------|:------|:--------|
| **Vercel** | Frontend apps, static sites, Next.js/React | Fastest | Platform-managed |
| **Self-Deploy** | Full-stack, databases, APIs, custom runtimes | Fast | Full control |

### When to use Vercel

- Frontend-only applications (Next.js, React, Vue, static)
- Rapid B2C product iteration
- Zero-config deployments with automatic previews
- Global CDN distribution out of the box
- No database requirements

### When to use Self-Deploy (Docker + Cloudflare Tunnel)

- Full-stack applications with databases
- Backend APIs, WebSocket servers, custom runtimes
- B2B/internal tools requiring flexibility
- No vendor limits or platform constraints
- Persistent URLs without platform lock-in

### Automatic Selection

Launch automatically recommends the optimal path based on your project:

```
Frontend-only (no DB) → Vercel
Has database/backend  → Docker + Cloudflare Tunnel
```

This keeps product rotation fast: validate frontend experiments on Vercel, ship full-stack MVPs with self-deploy.

---

## Architecture

Launch is designed for **token efficiency**:

- **4 core tools** always loaded (~400 tokens)
- **15 deferred tools** loaded via `search_tools` on demand
- **15 resources** for static platform/context data (zero tool-call overhead)

```
Core Tools (always available)
├── analyze      - Detect language, framework, database, complexity
├── recommend    - Get ranked platform recommendations
├── deploy       - Start deployment workflow
└── search_tools - Find additional tools

Deferred Tools (loaded on demand)
├── Generation   - Dockerfile, docker-compose, platform configs
└── Execution    - Docker, Vercel, Railway, Fly.io, tunnels

Resources (static data)
├── Platforms    - vercel, railway, render, fly, docker
├── Contexts     - mvp, b2c, b2b, saas, api, internal
└── Modes        - automated, guided, plan
```

---

## Tools

### Core Tools

| Tool | Description | Input |
|:-----|:------------|:------|
| `analyze` | Detect project characteristics | `{path}` |
| `recommend` | Ranked platform recommendations | `{framework, context, has_database?, complexity?}` |
| `deploy` | Start deployment workflow | `{path, mode, context?, platform?}` |
| `search_tools` | Find additional tools | `{query}` |

### Deferred Tools

Use `search_tools` to discover these:

**Generation:**
- `generate_dockerfile` - Create optimized Dockerfile
- `generate_docker_compose` - Create docker-compose.yml
- `generate_platform_config` - Create platform-specific config
- `preview_generated_files` - Preview before writing
- `check_deployment_readiness` - Validate requirements

**Execution:**
- `check_docker_status` - Verify Docker availability
- `deploy_to_docker` - Build and run container
- `deploy_to_vercel` - Deploy via Vercel CLI
- `deploy_to_railway` - Deploy via Railway CLI
- `deploy_to_fly` - Deploy via Fly.io CLI
- `setup_cloudflare_tunnel` - Create persistent tunnel
- `get_deployment_status` - Check deployment state
- `get_deployment_logs` - Retrieve logs
- `stop_deployment` - Stop running deployment
- `check_platform_cli` - Verify CLI installation

---

## Resources

Access static data without tool-call overhead:

```
launch://platforms          - List all platforms
launch://platforms/vercel   - Vercel details
launch://platforms/railway  - Railway details
launch://platforms/render   - Render details
launch://platforms/fly      - Fly.io details
launch://platforms/docker   - Docker details

launch://contexts           - List all contexts
launch://contexts/mvp       - MVP priorities
launch://contexts/b2c       - B2C priorities
launch://contexts/b2b       - B2B priorities
launch://contexts/saas      - SaaS priorities
launch://contexts/api       - API priorities
launch://contexts/internal  - Internal tool priorities

launch://modes              - List all modes
launch://modes/automated    - Fast deployment
launch://modes/guided       - Step-by-step
launch://modes/plan         - Analysis only
```

---

## Deployment Modes

| Mode | Description | User Input |
|:-----|:------------|:-----------|
| `automated` | Fast deployment with sensible defaults | Minimal |
| `guided` | Step-by-step with explanations | Each step |
| `plan` | Analysis and planning only | None |

---

## CLI Commands

```bash
launch install    # Register MCP server with Claude Code
launch uninstall  # Remove MCP server registration
launch doctor     # Verify configuration and dependencies
launch serve      # Start MCP server manually (stdio)
```

---

## Supported Platforms

| Platform | Type | Best For | Database |
|:---------|:-----|:---------|:---------|
| Vercel | Serverless | Next.js, React, Vue, static | No |
| Railway | PaaS | Express, FastAPI, Django, full-stack | Yes |
| Render | PaaS | Express, FastAPI, Django, Flask | Yes |
| Fly.io | Edge | Go, Rust, real-time, global | Yes |
| Docker | Self-hosted | Any framework, full control | Yes |

---

## Requirements

- Node.js >= 18.0.0
- Claude Code CLI (for registration)
- Docker (for Docker deployments)
- Platform CLIs as needed (vercel, railway, fly)

---

## Development

```bash
# Build
npm run build

# Watch mode
npm run dev

# Run tests
npm test

# Lint
npm run lint
```

---

## Project Structure

```
src/
├── index.ts           # MCP server entry point
├── cli/
│   └── index.ts       # CLI commands
├── tools/
│   ├── analyze.ts     # Project analysis
│   ├── recommend.ts   # Platform recommendations
│   ├── modes.ts       # Deployment modes
│   ├── generate.ts    # Config generation
│   └── execute.ts     # Deployment execution
├── resources/
│   └── index.ts       # Static MCP resources
└── utils/
    ├── config.ts      # Claude settings management
    ├── validation.ts  # Zod schemas
    └── version.ts     # Version export
```

---

## License

MIT
