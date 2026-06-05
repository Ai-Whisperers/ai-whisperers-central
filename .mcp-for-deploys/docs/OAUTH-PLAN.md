# OAuth PKCE Implementation Plan

**Doc-Type:** Implementation Plan · Version 1.0 · Updated 2025-12-16 · Author AI Whisperers

Seamless browser-based authentication for tokenless deployments.

---

## Goal

Replace "run `vercel login`" errors with automatic OAuth flows that open the browser, authenticate with one click (if already logged in), and store tokens securely - achieving true tokenless deployment from the user's perspective.

---

## Current State

```
execute.ts: checkCli() → authenticated? → No → "run vercel login" (friction)
```

**Problem:** User must manually run CLI login commands before deployment works.

---

## Target State

```
execute.ts: checkAuth() → authenticated? → No → openOAuthFlow() → browser opens → user clicks authorize → token stored → deploy proceeds
```

**Result:** If user is logged into platform in browser, deployment "just works" with one authorize click.

---

## Platform OAuth Analysis

| Platform | OAuth Support | Flow Type | Token Location | Notes |
|:---------|:--------------|:----------|:---------------|:------|
| Vercel | Yes | OAuth 2.0 + PKCE | `~/.launch/tokens/vercel.json` | Well-documented, standard flow |
| Railway | Partial | OAuth 2.0 | `~/.launch/tokens/railway.json` | Less documented, may need API |
| Fly.io | Yes | Device Authorization | `~/.launch/tokens/fly.json` | Different flow, displays code |
| Cloudflare | Yes | OAuth 2.0 | `~/.launch/tokens/cloudflare.json` | For API tokens, tunnel auth separate |

---

## Architecture

### New Files

```
src/
├── utils/
│   └── auth/
│       ├── index.ts        # Main auth coordinator
│       ├── oauth-server.ts # Local callback server
│       ├── token-store.ts  # Secure token storage
│       ├── vercel.ts       # Vercel OAuth implementation
│       ├── railway.ts      # Railway OAuth implementation
│       ├── fly.ts          # Fly.io device auth implementation
│       └── cloudflare.ts   # Cloudflare OAuth implementation
├── cli/
│   └── auth.ts             # CLI auth management command
```

### Dependencies to Add

```json
{
  "open": "^10.0.0",        // Open browser cross-platform
  "keytar": "^7.9.0"        // OS keychain integration (optional, for secure storage)
}
```

---

## Implementation Phases

### Phase 1: Core Infrastructure

**Files:** `src/utils/auth/index.ts`, `oauth-server.ts`, `token-store.ts`

1. **Token Store** (`token-store.ts`)
   - Read/write tokens to `~/.launch/tokens/`
   - Token format: `{ accessToken, refreshToken, expiresAt, scope }`
   - Auto-refresh when expired
   - Optional keychain integration via keytar

2. **OAuth Callback Server** (`oauth-server.ts`)
   - Spin up local HTTP server on random available port
   - Listen for OAuth callback with authorization code
   - Exchange code for tokens
   - Return tokens and shutdown server
   - Timeout after 5 minutes

3. **Auth Coordinator** (`index.ts`)
   - `checkAuth(platform)` - Check if valid token exists
   - `authenticate(platform)` - Trigger OAuth flow
   - `getToken(platform)` - Get valid token (refresh if needed)
   - `logout(platform)` - Remove stored token

### Phase 2: Platform Implementations

**Files:** `vercel.ts`, `railway.ts`, `fly.ts`, `cloudflare.ts`

1. **Vercel OAuth** (`vercel.ts`)
   ```
   OAuth URL: https://vercel.com/oauth/authorize
   Token URL: https://api.vercel.com/oauth/access_token
   Scopes: user, deployments:read, deployments:write
   ```
   - Register OAuth app at vercel.com/account/oauth-apps
   - Client ID stored in config (public)
   - PKCE flow (no client secret needed)

2. **Railway OAuth** (`railway.ts`)
   ```
   OAuth URL: https://railway.app/oauth/authorize
   Token URL: https://railway.app/oauth/token
   ```
   - May need to contact Railway for OAuth app
   - Fallback: Use CLI if OAuth unavailable

3. **Fly.io Device Auth** (`fly.ts`)
   ```
   Device Auth URL: https://fly.io/oauth/device/code
   Token URL: https://fly.io/oauth/token
   ```
   - Different flow: Display code, user enters in browser
   - Poll for token completion

4. **Cloudflare OAuth** (`cloudflare.ts`)
   ```
   OAuth URL: https://dash.cloudflare.com/oauth2/authorize
   Token URL: https://dash.cloudflare.com/oauth2/token
   ```
   - For API access, tunnel auth handled separately

### Phase 3: Integration

**Files:** `execute.ts`, `doctor.ts`, `cli/auth.ts`, `cli/index.ts`

1. **Update execute.ts**
   - Replace `checkCli()` calls with `checkAuth()` first
   - If no auth, call `authenticate()` instead of returning error
   - Use token for API calls OR pass to CLI

2. **Update doctor.ts**
   - Add auth status checks for each platform
   - Show which platforms have valid tokens

3. **New CLI command** (`cli/auth.ts`)
   ```bash
   launch auth status           # Show auth status for all platforms
   launch auth login vercel     # Manually trigger OAuth for platform
   launch auth logout vercel    # Remove stored token
   launch auth login --all      # Auth all platforms
   ```

4. **Update cli/index.ts**
   - Register new auth command

---

## OAuth Flow Sequence

```
User: "deploy my app to Vercel"
    │
    ▼
Claude calls deploy_to_vercel tool
    │
    ▼
execute.ts: checkAuth("vercel")
    │
    ├── Token exists & valid? → Use token → Deploy
    │
    └── No token? → authenticate("vercel")
                        │
                        ▼
                   Start local server on :3847
                        │
                        ▼
                   Open browser: vercel.com/oauth/authorize?
                        client_id=xxx&
                        redirect_uri=http://localhost:3847/callback&
                        code_challenge=xxx&
                        state=xxx
                        │
                        ▼
                   User sees Vercel auth page
                   (already logged in = one click)
                        │
                        ▼
                   Vercel redirects to localhost:3847/callback?code=xxx
                        │
                        ▼
                   Exchange code for tokens
                        │
                        ▼
                   Store tokens in ~/.launch/tokens/vercel.json
                        │
                        ▼
                   Return to deploy_to_vercel → Deploy succeeds
```

---

## Token Storage Format

```typescript
// ~/.launch/tokens/vercel.json
interface StoredToken {
  accessToken: string;
  refreshToken?: string;
  expiresAt: number;        // Unix timestamp
  scope: string;
  createdAt: number;
  platform: string;
}
```

---

## Security Considerations

1. **PKCE Required** - Prevents authorization code interception
2. **State Parameter** - Prevents CSRF attacks
3. **Localhost Only** - Callback server binds to 127.0.0.1 only
4. **Token Encryption** - Consider encrypting tokens at rest (keytar)
5. **Short-lived Server** - Callback server auto-closes after auth or timeout
6. **No Client Secrets** - Public clients use PKCE, no secrets in code

---

## Fallback Strategy

If OAuth fails or platform doesn't support it:

1. Check if CLI is installed and authenticated (current behavior)
2. If CLI auth exists, use CLI for deployment
3. If neither, provide clear instructions for CLI login

```typescript
async function ensureAuth(platform: string): Promise<AuthResult> {
  // Try Launch OAuth first
  if (await checkAuth(platform)) {
    return { type: "oauth", token: await getToken(platform) };
  }

  // Try OAuth flow
  try {
    await authenticate(platform);
    return { type: "oauth", token: await getToken(platform) };
  } catch {
    // Fallback to CLI
    if (await checkCliAuth(platform)) {
      return { type: "cli" };
    }

    throw new Error(`Not authenticated with ${platform}. Run: launch auth login ${platform}`);
  }
}
```

---

## CLI Auth Command Interface

```bash
$ launch auth status

Platform Authentication Status:

  ✓ Vercel     Authenticated (expires in 29 days)
  ✓ Railway    Authenticated (expires in 13 days)
  ✗ Fly.io     Not authenticated
  ✗ Cloudflare Not authenticated

Run 'launch auth login <platform>' to authenticate.

$ launch auth login vercel

Opening browser for Vercel authentication...
Waiting for authorization...
✓ Successfully authenticated with Vercel

$ launch auth logout vercel

✓ Logged out from Vercel
```

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|:-----|:-------|:-----------|
| Platform changes OAuth endpoints | Auth breaks | Version-pin OAuth configs, monitor changes |
| User blocks popup | Flow fails | Clear error message, fallback to CLI |
| Port conflict | Server can't start | Try multiple ports, clear error |
| Token refresh fails | Auth expires | Re-trigger full OAuth flow |
| Railway OAuth unavailable | Can't auth | Fallback to CLI only |

---

## Success Criteria

1. User can deploy to Vercel without ever running `vercel login`
2. User can deploy to Docker + Cloudflare tunnel without manual tunnel setup
3. `launch doctor` shows auth status for all platforms
4. `launch auth` provides manual control over authentication
5. Existing CLI-based auth continues to work as fallback

---

## Estimated Effort

| Phase | Scope | Complexity |
|:------|:------|:-----------|
| Phase 1 | Core infrastructure | Medium |
| Phase 2 | Platform implementations | High (4 platforms) |
| Phase 3 | Integration | Medium |
| Testing | End-to-end flows | Medium |

---

## Dependencies

- OAuth app registration with each platform (one-time setup)
- Platform API documentation review
- Testing accounts on each platform

---

## Next Steps

1. Register OAuth app with Vercel (requires Vercel account)
2. Implement Phase 1 core infrastructure
3. Implement Vercel OAuth as proof of concept
4. Test end-to-end flow
5. Implement remaining platforms
6. Integration and CLI updates
