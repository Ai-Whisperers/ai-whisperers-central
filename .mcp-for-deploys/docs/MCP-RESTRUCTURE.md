# Launch MCP - Restructuring Based on Anthropic Best Practices

**Doc-Type:** Technical Analysis · Version 1.0 · Updated 2025-12-16 · Author AI Whisperers

---

## Executive Summary

Current implementation has 27 tools that violate MCP best practices. This document outlines issues and proposes restructuring to align with Anthropic's guidelines for token-efficient, well-designed MCP servers.

---

## Current Issues

### Issue 1: Token-Heavy Mode Tools

**Problem:** Mode tools (`start_automated_deploy`, `start_guided_deploy`, `start_plan_mode`) return large `instructions_for_claude` text blocks embedded in JSON responses.

**Example of current anti-pattern:**
```json
{
  "mode": "automated",
  "instructions_for_claude": "\nYou are now in AUTOMATED deployment mode. Follow these steps in order:\n\n1. Call analyze_codebase with path...\n2. Call recommend_deployment...\n[200+ tokens of instructions]"
}
```

**Why it's wrong:**
- Consumes tokens on every mode invocation
- Claude already knows how to orchestrate tools
- Instructions should be in system prompt or server description, not tool responses

**Fix:** Return minimal structured data. Let Claude's own reasoning handle orchestration.

---

### Issue 2: All 27 Tools Load at Once

**Problem:** No progressive discovery. Every conversation loads all tool definitions into context.

**Current state:**
- 27 tools × ~100 tokens each = ~2,700 tokens consumed before first user message
- Many tools rarely used (e.g., `compare_platforms`, `list_commercial_contexts`)

**Anthropic recommendation:** Use `defer_loading: true` and a search tool.

**Fix:**
- Mark 20+ tools as `defer_loading: true`
- Add `search_launch_tools` tool for discovery
- Keep only 5-7 core tools always loaded

---

### Issue 3: Static Content as Tools Instead of Resources

**Problem:** Tools like `get_platform_details`, `list_commercial_contexts`, `get_mode_details` return static data that doesn't change.

**MCP distinction:**
| Aspect | Tools | Resources |
|--------|-------|-----------|
| Control | Model-controlled | App-controlled |
| Use case | Dynamic actions | Static context |
| Token cost | High (schema + response) | Low (cached, on-demand) |

**Current anti-pattern tools:**
- `get_platform_details` - Static platform info
- `list_commercial_contexts` - Static context definitions
- `get_mode_details` - Static mode descriptions
- `compare_platforms` - Could be a resource template
- `list_deployment_modes` - Static list

**Fix:** Convert to MCP Resources:
```
resources://launch/platforms/vercel
resources://launch/platforms/railway
resources://launch/contexts/b2b
resources://launch/modes/automated
```

---

### Issue 4: Verbose Tool Responses

**Problem:** Tool responses include explanatory text, suggestions, and formatting meant for humans.

**Example anti-pattern:**
```json
{
  "success": true,
  "image": "myapp",
  "container": "myapp",
  "port": 3000,
  "url": "http://localhost:3000",
  "tunnel_note": "Use setup_cloudflare_tunnel tool to create a named tunnel for persistent access"
}
```

**Why it's wrong:**
- `tunnel_note` is instruction for Claude, wastes tokens
- Claude can infer next steps from context

**Fix:** Return only essential data:
```json
{
  "success": true,
  "container_id": "abc123",
  "port": 3000,
  "url": "http://localhost:3000"
}
```

---

### Issue 5: Generic Tool Names

**Problem:** Some tools use generic patterns instead of domain-specific names.

**Current:**
- `generate_platform_config` (generic)
- `check_deployment_status` (too broad)

**Better:**
- `generate_vercel_config`, `generate_railway_config` (specific)
- `get_docker_container_status`, `get_vercel_deployment_status` (specific)

**Trade-off:** More tools but clearer intent. With `defer_loading`, this is acceptable.

---

### Issue 6: No Input Validation

**Problem:** Tools trust all input without validation.

**Current anti-pattern:**
```typescript
const params = args as { path: string; framework: string };
// No validation, directly used
```

**Risk:** Path traversal, injection attacks, undefined behavior.

**Fix:** Use Zod schemas for runtime validation:
```typescript
const schema = z.object({
  path: z.string().min(1).refine(p => existsSync(p)),
  framework: z.enum(['nextjs', 'react', 'express', ...])
});
const params = schema.parse(args);
```

---

### Issue 7: No Structured Output Schema

**Problem:** Tools don't declare `outputSchema`, making responses unpredictable.

**Anthropic recommendation:** Provide `outputSchema` for consistent, parseable responses.

**Fix:** Add output schemas to tool definitions:
```typescript
{
  name: "deploy_to_docker",
  inputSchema: { ... },
  outputSchema: {
    type: "object",
    properties: {
      success: { type: "boolean" },
      container_id: { type: "string" },
      url: { type: "string" }
    }
  }
}
```

---

### Issue 8: Missing Error Context

**Problem:** Errors returned as protocol-level failures or generic messages.

**Anthropic recommendation:** Report errors within result object so Claude can handle them.

**Fix:** Standardized error response:
```json
{
  "success": false,
  "error": {
    "code": "DOCKER_NOT_RUNNING",
    "message": "Docker daemon is not accessible",
    "recoverable": true,
    "suggested_action": "start_docker"
  }
}
```

---

## Proposed Restructure

### Core Tools (Always Loaded) - 7 tools

| Tool | Purpose |
|------|---------|
| `analyze_project` | Unified analysis (replaces 3 tools) |
| `recommend_platform` | Get top recommendation |
| `generate_config` | Generate deployment config |
| `deploy` | Execute deployment |
| `get_status` | Check deployment status |
| `get_logs` | Retrieve logs |
| `search_tools` | Progressive discovery |

### Deferred Tools (defer_loading: true) - 12 tools

| Tool | Purpose |
|------|---------|
| `deploy_to_docker` | Docker-specific deployment |
| `deploy_to_vercel` | Vercel-specific deployment |
| `deploy_to_railway` | Railway-specific deployment |
| `deploy_to_fly` | Fly.io-specific deployment |
| `setup_tunnel` | Cloudflare tunnel setup |
| `stop_deployment` | Stop running deployment |
| `restart_deployment` | Restart deployment |
| `check_docker` | Docker daemon status |
| `check_cli` | Platform CLI status |
| `generate_dockerfile` | Dockerfile generation |
| `generate_compose` | Docker Compose generation |
| `validate_config` | Pre-deploy validation |

### Resources (Static Content) - 8 resources

| Resource URI | Content |
|--------------|---------|
| `launch://platforms` | List of all platforms |
| `launch://platforms/{name}` | Platform details |
| `launch://contexts` | Commercial contexts |
| `launch://contexts/{name}` | Context details |
| `launch://modes` | Deployment modes |
| `launch://modes/{name}` | Mode details |
| `launch://tutorials/{topic}` | Deployment tutorials |
| `launch://troubleshooting/{issue}` | Common fixes |

### Removed/Merged Tools

| Old Tool | Action |
|----------|--------|
| `detect_project_type` | Merged into `analyze_project` |
| `list_project_files` | Merged into `analyze_project` |
| `get_platform_details` | Converted to Resource |
| `compare_platforms` | Converted to Resource |
| `list_commercial_contexts` | Converted to Resource |
| `list_deployment_modes` | Converted to Resource |
| `get_mode_details` | Converted to Resource |
| `preview_generated_files` | Removed (low value) |
| `start_automated_deploy` | Simplified to just `deploy` with mode param |
| `start_guided_deploy` | Simplified to just `deploy` with mode param |
| `start_plan_mode` | Simplified to just `analyze_project` with plan output |

---

## Implementation Priority

### Phase A: Token Efficiency (Critical)

1. Remove `instructions_for_claude` from all responses
2. Add `defer_loading: true` to 12+ tools
3. Implement `search_tools` for progressive discovery
4. Trim verbose responses to essential data only

### Phase B: Resources (High)

1. Implement MCP Resources handler
2. Convert 5 static-data tools to Resources
3. Add resource templates for dynamic queries

### Phase C: Validation & Errors (Medium)

1. Add Zod schemas for input validation
2. Add `outputSchema` to tool definitions
3. Standardize error response format

### Phase D: Tool Consolidation (Medium)

1. Merge analysis tools into `analyze_project`
2. Merge mode tools into unified `deploy` with mode parameter
3. Remove low-value tools

---

## Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Tools always loaded | 27 | 7 |
| Tokens per tool list | ~2,700 | ~700 |
| Response verbosity | High | Minimal |
| Static data as Resources | 0 | 8 |
| Input validation | None | 100% |
| Output schemas defined | 0% | 100% |

---

## References

- [Code execution with MCP: Building more efficient agents](https://www.anthropic.com/engineering/code-execution-with-mcp)
- [Model Context Protocol Specification](https://modelcontextprotocol.io/)
- [MCP Tool Design Best Practices](https://oshea00.github.io/posts/mcp-practices/)

---

## Next Steps

1. Review and approve this restructuring plan
2. Implement Phase A (token efficiency) first
3. Write tests before refactoring
4. Update README with new tool/resource structure
