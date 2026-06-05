# Self-Deploy Infrastructure Plan

**Doc-Type:** Implementation Plan · Version 1.0 · Updated 2025-12-16 · Author AI Whisperers

Self-deploy via Docker + Cloudflare Tunnel as the quickest path to production.

---

## Goal

Zero-friction self-deployment: detect environment, ensure Docker runs efficiently (WSL2 preferred), manage Cloudflared lifecycle, and authenticate via browser/credentials/tokens.

---

## Architecture Overview

```
src/
├── utils/
│   └── environment/
│       ├── index.ts          # Environment coordinator
│       ├── os-detect.ts      # OS/platform detection
│       ├── docker-setup.ts   # Docker installation/configuration
│       ├── wsl.ts            # WSL2 management (Windows)
│       └── cloudflared.ts    # Cloudflared lifecycle management
```

---

## Phase 1: OS Environment Detection

### Detection Matrix

| Check | Windows | WSL2 | macOS | Linux |
|:------|:--------|:-----|:------|:------|
| `process.platform` | `win32` | `linux` | `darwin` | `linux` |
| WSL detection | N/A | `WSL_DISTRO_NAME` env | N/A | N/A |
| Docker socket | `//./pipe/docker_engine` | `/var/run/docker.sock` | `/var/run/docker.sock` | `/var/run/docker.sock` |
| Cloudflared binary | `cloudflared.exe` | `cloudflared` | `cloudflared` | `cloudflared` |
| Package manager | `winget`/`choco`/`scoop` | `apt`/`snap` | `brew` | `apt`/`yum`/`dnf` |

### Implementation: `os-detect.ts`

```typescript
interface EnvironmentInfo {
  os: "windows" | "macos" | "linux";
  isWSL: boolean;
  wslDistro?: string;
  arch: "x64" | "arm64";
  dockerSocket: string;
  packageManager: string[];
  cloudflaredBinary: string;
  cloudflaredConfigDir: string;
}

function detectEnvironment(): EnvironmentInfo {
  const platform = process.platform;
  const isWSL = !!process.env.WSL_DISTRO_NAME;

  if (platform === "win32") {
    return {
      os: "windows",
      isWSL: false,
      arch: process.arch as "x64" | "arm64",
      dockerSocket: "//./pipe/docker_engine",
      packageManager: detectWindowsPackageManager(), // winget, choco, scoop
      cloudflaredBinary: "cloudflared.exe",
      cloudflaredConfigDir: join(process.env.USERPROFILE!, ".cloudflared"),
    };
  }

  if (platform === "linux" && isWSL) {
    return {
      os: "linux",
      isWSL: true,
      wslDistro: process.env.WSL_DISTRO_NAME,
      arch: process.arch as "x64" | "arm64",
      dockerSocket: "/var/run/docker.sock",
      packageManager: ["apt", "snap"],
      cloudflaredBinary: "cloudflared",
      cloudflaredConfigDir: join(process.env.HOME!, ".cloudflared"),
    };
  }

  // ... macOS and native Linux
}
```

---

## Phase 2: Docker Setup Strategy

### Priority Order

1. **WSL2 Docker** (Windows) - Lowest overhead, native Linux containers
2. **Native Docker** (Linux/macOS) - Direct installation
3. **Docker Desktop** (Fallback) - Works but resource-heavy

### WSL2 Docker Setup (Windows)

```typescript
interface DockerSetupResult {
  method: "wsl2" | "docker-desktop" | "native";
  ready: boolean;
  steps?: string[];
}

async function setupDocker(): Promise<DockerSetupResult> {
  const env = detectEnvironment();

  if (env.os === "windows") {
    // Check WSL2 availability
    const wslStatus = await checkWSL2();

    if (wslStatus.installed && wslStatus.version === 2) {
      // Check if Docker is installed in WSL
      const wslDocker = await checkDockerInWSL(wslStatus.defaultDistro);

      if (wslDocker.installed) {
        return { method: "wsl2", ready: true };
      }

      // Install Docker in WSL
      return {
        method: "wsl2",
        ready: false,
        steps: [
          "Installing Docker in WSL2...",
          `wsl -d ${wslStatus.defaultDistro} -- sudo apt update`,
          `wsl -d ${wslStatus.defaultDistro} -- sudo apt install -y docker.io`,
          `wsl -d ${wslStatus.defaultDistro} -- sudo usermod -aG docker $USER`,
        ],
      };
    }

    // Fallback to Docker Desktop
    return await checkDockerDesktop();
  }

  // Linux/macOS - native Docker
  return await checkNativeDocker();
}
```

### WSL2 Commands

```bash
# Check WSL version
wsl --list --verbose

# Install Docker in WSL2 (Ubuntu)
wsl -d Ubuntu-22.04 -- bash -c "
  sudo apt update &&
  sudo apt install -y docker.io docker-compose &&
  sudo usermod -aG docker $USER &&
  sudo service docker start
"

# Run Docker command in WSL
wsl -d Ubuntu-22.04 -- docker ps

# Access WSL Docker from Windows
# Set DOCKER_HOST=tcp://localhost:2375 or use WSL Docker socket
```

### Docker Desktop Detection (Fallback)

```typescript
async function checkDockerDesktop(): Promise<DockerSetupResult> {
  // Check if Docker Desktop is installed
  const desktopPaths = [
    "C:\\Program Files\\Docker\\Docker\\Docker Desktop.exe",
    join(process.env.LOCALAPPDATA!, "Docker\\Docker Desktop.exe"),
  ];

  const installed = desktopPaths.some(existsSync);

  if (installed) {
    // Check if running
    const running = await checkDockerDaemon();
    return {
      method: "docker-desktop",
      ready: running,
      steps: running ? undefined : ["Start Docker Desktop application"],
    };
  }

  return {
    method: "docker-desktop",
    ready: false,
    steps: [
      "Docker not found. Options:",
      "1. (Recommended) Install Docker in WSL2 for lower overhead",
      "2. Install Docker Desktop from https://docker.com",
    ],
  };
}
```

---

## Phase 3: Cloudflared Management

### Binary Management

```typescript
interface CloudflaredStatus {
  installed: boolean;
  version?: string;
  latestVersion?: string;
  needsUpdate: boolean;
  authenticated: boolean;
  authMethod?: "browser" | "credentials" | "token";
  configPath: string;
}

async function checkCloudflared(): Promise<CloudflaredStatus> {
  const env = detectEnvironment();
  const binary = env.cloudflaredBinary;

  // Check installation
  const installed = await commandExists(binary);
  if (!installed) {
    return {
      installed: false,
      needsUpdate: false,
      authenticated: false,
      configPath: env.cloudflaredConfigDir,
    };
  }

  // Get versions
  const version = await getVersion(binary);
  const latestVersion = await getLatestCloudflaredVersion();

  // Check authentication
  const authStatus = await checkCloudflaredAuth(env.cloudflaredConfigDir);

  return {
    installed: true,
    version,
    latestVersion,
    needsUpdate: version !== latestVersion,
    authenticated: authStatus.authenticated,
    authMethod: authStatus.method,
    configPath: env.cloudflaredConfigDir,
  };
}
```

### Installation by Platform

```typescript
async function installCloudflared(): Promise<void> {
  const env = detectEnvironment();

  switch (env.os) {
    case "windows":
      // Try winget first, then choco, then scoop, then direct download
      if (env.packageManager.includes("winget")) {
        await execa("winget", ["install", "Cloudflare.cloudflared"]);
      } else {
        await downloadCloudflared("windows", env.arch);
      }
      break;

    case "linux":
      if (env.isWSL) {
        // Install in WSL
        await execa("wsl", ["-d", env.wslDistro!, "--", "bash", "-c",
          "curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg && " +
          "echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main' | sudo tee /etc/apt/sources.list.d/cloudflared.list && " +
          "sudo apt update && sudo apt install -y cloudflared"
        ]);
      } else {
        // Native Linux
        await execa("bash", ["-c",
          "curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg && " +
          "echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main' | sudo tee /etc/apt/sources.list.d/cloudflared.list && " +
          "sudo apt update && sudo apt install -y cloudflared"
        ]);
      }
      break;

    case "macos":
      await execa("brew", ["install", "cloudflared"]);
      break;
  }
}

async function downloadCloudflared(os: string, arch: string): Promise<void> {
  const releases = {
    "windows-x64": "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe",
    "windows-arm64": "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-arm64.exe",
    "linux-x64": "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64",
    "linux-arm64": "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64",
    "macos-x64": "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-amd64.tgz",
    "macos-arm64": "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-arm64.tgz",
  };

  const url = releases[`${os}-${arch}`];
  // Download and install to appropriate location
}
```

### Auto-Update Check

```typescript
async function getLatestCloudflaredVersion(): Promise<string> {
  // Check GitHub releases API
  const response = await fetch(
    "https://api.github.com/repos/cloudflare/cloudflared/releases/latest"
  );
  const data = await response.json();
  return data.tag_name; // e.g., "2024.1.5"
}

async function updateCloudflared(): Promise<void> {
  const env = detectEnvironment();

  if (env.os === "windows" && env.packageManager.includes("winget")) {
    await execa("winget", ["upgrade", "Cloudflare.cloudflared"]);
  } else if (env.os === "macos") {
    await execa("brew", ["upgrade", "cloudflared"]);
  } else {
    // Re-download latest
    await downloadCloudflared(env.os, env.arch);
  }
}
```

---

## Phase 4: Cloudflare Authentication

### Three Authentication Methods

#### 1. Browser Authentication (Interactive)

```typescript
async function authViaBrowser(): Promise<AuthResult> {
  // Opens browser to Cloudflare login
  // User authorizes, cert.pem downloaded to ~/.cloudflared/
  await execa("cloudflared", ["tunnel", "login"]);

  // Verify cert exists
  const certPath = join(getConfigDir(), "cert.pem");
  if (existsSync(certPath)) {
    return { success: true, method: "browser", certPath };
  }

  throw new Error("Authentication failed - cert.pem not found");
}
```

#### 2. Credentials File Authentication

```typescript
interface TunnelCredentials {
  AccountTag: string;
  TunnelID: string;
  TunnelSecret: string;
}

async function authViaCredentials(credentialsPath: string): Promise<AuthResult> {
  // User provides credentials JSON from Cloudflare dashboard
  // Tunnel > Create Tunnel > Download credentials

  if (!existsSync(credentialsPath)) {
    throw new Error(`Credentials file not found: ${credentialsPath}`);
  }

  const creds: TunnelCredentials = JSON.parse(readFileSync(credentialsPath, "utf-8"));

  // Copy to config directory
  const targetPath = join(getConfigDir(), `${creds.TunnelID}.json`);
  copyFileSync(credentialsPath, targetPath);

  return { success: true, method: "credentials", tunnelId: creds.TunnelID };
}
```

#### 3. API Token Authentication

```typescript
async function authViaToken(apiToken: string): Promise<AuthResult> {
  // User provides API token from Cloudflare dashboard
  // Profile > API Tokens > Create Token
  // Permissions: Account:Cloudflare Tunnel:Edit

  // Store token for API calls
  const tokenPath = join(getConfigDir(), "api-token");
  writeFileSync(tokenPath, apiToken, { mode: 0o600 });

  // Verify token works
  const response = await fetch("https://api.cloudflare.com/client/v4/user/tokens/verify", {
    headers: { "Authorization": `Bearer ${apiToken}` },
  });

  if (!response.ok) {
    throw new Error("Invalid API token");
  }

  return { success: true, method: "token" };
}
```

### Authentication Check

```typescript
interface AuthStatus {
  authenticated: boolean;
  method?: "browser" | "credentials" | "token";
  certPath?: string;
  tunnelId?: string;
  expiresAt?: Date;
}

async function checkCloudflaredAuth(configDir: string): Promise<AuthStatus> {
  // Check for cert.pem (browser auth)
  const certPath = join(configDir, "cert.pem");
  if (existsSync(certPath)) {
    return { authenticated: true, method: "browser", certPath };
  }

  // Check for tunnel credentials
  const credFiles = readdirSync(configDir).filter(f => f.endsWith(".json"));
  for (const file of credFiles) {
    try {
      const creds = JSON.parse(readFileSync(join(configDir, file), "utf-8"));
      if (creds.TunnelID && creds.TunnelSecret) {
        return { authenticated: true, method: "credentials", tunnelId: creds.TunnelID };
      }
    } catch { continue; }
  }

  // Check for API token
  const tokenPath = join(configDir, "api-token");
  if (existsSync(tokenPath)) {
    return { authenticated: true, method: "token" };
  }

  return { authenticated: false };
}
```

---

## Phase 5: Integration with execute.ts

### Updated Self-Deploy Flow

```typescript
async function deployToDocker(params: DeployParams): Promise<ToolResponse> {
  // 1. Detect environment
  const env = detectEnvironment();

  // 2. Ensure Docker is ready
  const dockerStatus = await setupDocker();
  if (!dockerStatus.ready) {
    return {
      content: [{
        type: "text",
        text: JSON.stringify({
          success: false,
          error: "Docker not ready",
          steps: dockerStatus.steps,
          recommendation: env.os === "windows"
            ? "WSL2 Docker recommended for lower overhead"
            : "Install Docker",
        }),
      }],
    };
  }

  // 3. Build and run container
  const buildResult = await buildDockerImage(params.path, params.imageName);
  if (!buildResult.success) {
    return errorResponse("build", buildResult.error);
  }

  const runResult = await runDockerContainer(/*...*/);
  if (!runResult.success) {
    return errorResponse("run", runResult.error);
  }

  // 4. Setup tunnel if requested
  if (params.setupTunnel) {
    const tunnelResult = await setupTunnel(params.tunnelName, params.port);
    return {
      content: [{
        type: "text",
        text: JSON.stringify({
          success: true,
          container: runResult.containerId,
          localUrl: `http://localhost:${params.port}`,
          publicUrl: tunnelResult.url,
          tunnel: tunnelResult.tunnelId,
        }),
      }],
    };
  }

  return successResponse(runResult);
}

async function setupTunnel(name: string, port: number): Promise<TunnelResult> {
  // 1. Ensure cloudflared is installed and updated
  const cfStatus = await checkCloudflared();

  if (!cfStatus.installed) {
    await installCloudflared();
  } else if (cfStatus.needsUpdate) {
    await updateCloudflared();
  }

  // 2. Ensure authenticated
  if (!cfStatus.authenticated) {
    // Try browser auth (opens Cloudflare login)
    await authViaBrowser();
  }

  // 3. Create/get tunnel
  const tunnel = await createOrGetTunnel(name);

  // 4. Start tunnel
  await startTunnel(tunnel.id, port);

  return {
    tunnelId: tunnel.id,
    url: `https://${tunnel.id}.cfargotunnel.com`,
  };
}
```

---

## CLI Commands

```bash
# Environment check
launch doctor --verbose

# Docker setup
launch setup docker           # Auto-detect best method
launch setup docker --wsl2    # Force WSL2 Docker
launch setup docker --desktop # Use Docker Desktop

# Cloudflared management
launch setup cloudflared                    # Install/update cloudflared
launch auth cloudflare                      # Browser auth
launch auth cloudflare --credentials <path> # Use credentials file
launch auth cloudflare --token <token>      # Use API token

# Full self-deploy
launch deploy --self          # Docker + auto tunnel
```

---

## New CLI Command: `launch setup`

```typescript
// cli/setup.ts
program
  .command("setup <component>")
  .description("Setup deployment infrastructure")
  .option("--wsl2", "Use WSL2 Docker (Windows)")
  .option("--desktop", "Use Docker Desktop")
  .action(async (component, options) => {
    switch (component) {
      case "docker":
        await setupDockerInteractive(options);
        break;
      case "cloudflared":
        await setupCloudflaredInteractive();
        break;
      case "all":
        await setupDockerInteractive(options);
        await setupCloudflaredInteractive();
        break;
    }
  });
```

---

## Updated `launch doctor` Output

```
$ launch doctor --verbose

Launch MCP Doctor v0.1.0

Environment:
  ✓ OS: Windows 11 (win32)
  ✓ Architecture: x64
  ✓ WSL2: Ubuntu-22.04 (running)

Docker:
  ✓ Docker in WSL2: 24.0.7 (recommended)
  ! Docker Desktop: Installed but not used (saves ~2GB RAM)

Cloudflared:
  ✓ Installed: 2024.1.5
  ✓ Latest: 2024.1.5 (up to date)
  ✓ Authenticated: Browser (cert.pem)

Platform CLIs:
  ✓ Vercel CLI: 33.0.0
  ✗ Railway CLI: Not installed
  ✓ Fly CLI: 0.2.0

Claude Code:
  ✓ Launch registered

Summary: 9 passed, 1 warning, 0 failed
```

---

## File Structure After Implementation

```
src/
├── utils/
│   ├── environment/
│   │   ├── index.ts          # detectEnvironment(), main coordinator
│   │   ├── os-detect.ts      # OS/arch/package manager detection
│   │   ├── docker-setup.ts   # Docker installation, WSL2 preference
│   │   ├── wsl.ts            # WSL2-specific operations
│   │   └── cloudflared.ts    # Install, update, auth management
│   ├── auth/                 # (from OAuth plan)
│   ├── config.ts
│   └── validation.ts
├── cli/
│   ├── index.ts
│   ├── setup.ts              # New: launch setup command
│   ├── doctor.ts             # Updated: environment checks
│   └── ...
├── tools/
│   ├── execute.ts            # Updated: use environment detection
│   └── ...
```

---

## Success Criteria

1. `launch doctor` shows complete environment status
2. `launch setup docker` configures WSL2 Docker on Windows automatically
3. `launch setup cloudflared` installs latest cloudflared
4. Three auth methods work: browser, credentials, token
5. `deploy_to_docker` with `setup_tunnel: true` works end-to-end
6. Auto-update check for cloudflared on each use

---

## Next Steps

1. Implement `os-detect.ts` with full platform detection
2. Implement `docker-setup.ts` with WSL2 preference
3. Implement `cloudflared.ts` with install/update/auth
4. Update `doctor.ts` with environment checks
5. Add `setup` CLI command
6. Integrate into `execute.ts`
