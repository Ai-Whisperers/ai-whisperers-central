/**
 * Deployment Execution Tools - Execute deployments via APIs and CLIs
 *
 * Uses dockerode for Docker API, execa for CLI commands with proper validation.
 */

import { Tool, CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import Docker from "dockerode";
import { execa, ExecaError } from "execa";
import { existsSync, writeFileSync } from "fs";
import { join } from "path";

type ToolResponse = CallToolResult;

// Initialize Docker client
const docker = new Docker();

/**
 * Check if a CLI tool is installed and authenticated
 */
async function checkCli(
  command: string,
  authCheck?: string[]
): Promise<{ installed: boolean; authenticated: boolean; version?: string }> {
  try {
    const { stdout } = await execa(command, ["--version"]);
    const version = stdout.trim().split("\n")[0];

    let authenticated = true;
    if (authCheck) {
      try {
        await execa(command, authCheck);
      } catch {
        authenticated = false;
      }
    }

    return { installed: true, authenticated, version };
  } catch {
    return { installed: false, authenticated: false };
  }
}

/**
 * Check Docker daemon status
 */
async function checkDocker(): Promise<{
  running: boolean;
  version?: string;
  error?: string;
}> {
  try {
    const info = await docker.version();
    return { running: true, version: info.Version };
  } catch (error) {
    return {
      running: false,
      error: error instanceof Error ? error.message : "Docker daemon not accessible",
    };
  }
}

/**
 * Build Docker image with progress streaming
 */
async function buildDockerImage(
  contextPath: string,
  imageName: string,
  tag: string = "latest"
): Promise<{ success: boolean; imageId?: string; error?: string; logs: string[] }> {
  const logs: string[] = [];

  try {
    const stream = await docker.buildImage(
      {
        context: contextPath,
        src: ["."],
      },
      { t: `${imageName}:${tag}` }
    );

    return new Promise((resolve) => {
      docker.modem.followProgress(
        stream,
        (err, output) => {
          if (err) {
            resolve({ success: false, error: err.message, logs });
          } else {
            const lastOutput = output[output.length - 1];
            const imageId = lastOutput?.aux?.ID;
            resolve({ success: true, imageId, logs });
          }
        },
        (event) => {
          if (event.stream) {
            logs.push(event.stream.trim());
          }
          if (event.error) {
            logs.push(`ERROR: ${event.error}`);
          }
        }
      );
    });
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Build failed",
      logs,
    };
  }
}

/**
 * Run Docker container
 */
async function runDockerContainer(
  imageName: string,
  containerName: string,
  port: number,
  envVars: Record<string, string> = {}
): Promise<{ success: boolean; containerId?: string; error?: string }> {
  try {
    // Remove existing container with same name if exists
    try {
      const existing = docker.getContainer(containerName);
      await existing.stop();
      await existing.remove();
    } catch {
      // Container doesn't exist, continue
    }

    const container = await docker.createContainer({
      Image: imageName,
      name: containerName,
      ExposedPorts: { [`${port}/tcp`]: {} },
      HostConfig: {
        PortBindings: {
          [`${port}/tcp`]: [{ HostPort: String(port) }],
        },
        RestartPolicy: { Name: "unless-stopped" },
      },
      Env: Object.entries(envVars).map(([k, v]) => `${k}=${v}`),
    });

    await container.start();

    return { success: true, containerId: container.id };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Container start failed",
    };
  }
}

/**
 * Get container health status
 */
async function getContainerHealth(
  containerName: string
): Promise<{ running: boolean; status?: string; health?: string }> {
  try {
    const container = docker.getContainer(containerName);
    const info = await container.inspect();

    return {
      running: info.State.Running,
      status: info.State.Status,
      health: info.State.Health?.Status,
    };
  } catch {
    return { running: false };
  }
}

/**
 * Register execution tools
 */
export function registerExecutionTools(): Tool[] {
  return [
    {
      name: "check_docker_status",
      description: "Check if Docker daemon is running and accessible",
      inputSchema: {
        type: "object" as const,
        properties: {},
      },
    },
    {
      name: "deploy_to_docker",
      description:
        "Build and run a Docker container locally. Optionally set up Cloudflare tunnel for public access.",
      inputSchema: {
        type: "object" as const,
        properties: {
          path: {
            type: "string",
            description: "Path to the project with Dockerfile",
          },
          image_name: {
            type: "string",
            description: "Name for the Docker image",
          },
          container_name: {
            type: "string",
            description: "Name for the container",
          },
          port: {
            type: "number",
            description: "Port to expose (default: 3000)",
          },
          env_vars: {
            type: "object",
            description: "Environment variables to pass to the container",
          },
          setup_tunnel: {
            type: "boolean",
            description: "Set up Cloudflare tunnel for public access",
          },
        },
        required: ["path", "image_name"],
      },
    },
    {
      name: "check_platform_cli",
      description:
        "Check if a platform CLI is installed and authenticated (vercel, railway, fly, cloudflared)",
      inputSchema: {
        type: "object" as const,
        properties: {
          platform: {
            type: "string",
            enum: ["vercel", "railway", "fly", "cloudflared"],
            description: "Platform CLI to check",
          },
        },
        required: ["platform"],
      },
    },
    {
      name: "deploy_to_vercel",
      description: "Deploy project to Vercel using the Vercel CLI",
      inputSchema: {
        type: "object" as const,
        properties: {
          path: {
            type: "string",
            description: "Path to the project",
          },
          production: {
            type: "boolean",
            description: "Deploy to production (default: false for preview)",
          },
          env_vars: {
            type: "object",
            description: "Environment variables to set",
          },
        },
        required: ["path"],
      },
    },
    {
      name: "deploy_to_railway",
      description: "Deploy project to Railway using the Railway CLI",
      inputSchema: {
        type: "object" as const,
        properties: {
          path: {
            type: "string",
            description: "Path to the project",
          },
          service_name: {
            type: "string",
            description: "Name for the Railway service",
          },
        },
        required: ["path"],
      },
    },
    {
      name: "deploy_to_fly",
      description: "Deploy project to Fly.io using the Fly CLI",
      inputSchema: {
        type: "object" as const,
        properties: {
          path: {
            type: "string",
            description: "Path to the project",
          },
          app_name: {
            type: "string",
            description: "Fly.io app name",
          },
          region: {
            type: "string",
            description: "Primary region (default: iad)",
          },
        },
        required: ["path"],
      },
    },
    {
      name: "setup_cloudflare_tunnel",
      description:
        "Set up a named Cloudflare tunnel for persistent public access to local services",
      inputSchema: {
        type: "object" as const,
        properties: {
          tunnel_name: {
            type: "string",
            description: "Name for the tunnel",
          },
          local_port: {
            type: "number",
            description: "Local port to tunnel",
          },
          hostname: {
            type: "string",
            description: "Custom hostname (requires Cloudflare domain)",
          },
        },
        required: ["tunnel_name", "local_port"],
      },
    },
    {
      name: "get_deployment_status",
      description: "Get status of a Docker container or platform deployment",
      inputSchema: {
        type: "object" as const,
        properties: {
          type: {
            type: "string",
            enum: ["docker", "vercel", "railway", "fly"],
            description: "Deployment type",
          },
          name: {
            type: "string",
            description: "Container name or project name",
          },
        },
        required: ["type", "name"],
      },
    },
    {
      name: "get_deployment_logs",
      description: "Get logs from a Docker container or platform deployment",
      inputSchema: {
        type: "object" as const,
        properties: {
          type: {
            type: "string",
            enum: ["docker", "vercel", "railway", "fly"],
            description: "Deployment type",
          },
          name: {
            type: "string",
            description: "Container name or project name",
          },
          tail: {
            type: "number",
            description: "Number of lines to retrieve (default: 100)",
          },
        },
        required: ["type", "name"],
      },
    },
    {
      name: "stop_deployment",
      description: "Stop a Docker container or scale down a platform deployment",
      inputSchema: {
        type: "object" as const,
        properties: {
          type: {
            type: "string",
            enum: ["docker", "vercel", "railway", "fly"],
            description: "Deployment type",
          },
          name: {
            type: "string",
            description: "Container name or project name",
          },
        },
        required: ["type", "name"],
      },
    },
  ];
}

/**
 * Handle execution tool calls
 */
export async function handleExecutionTool(
  name: string,
  args: unknown
): Promise<ToolResponse | null> {
  switch (name) {
    case "check_docker_status": {
      const status = await checkDocker();
      return {
        content: [
          {
            type: "text" as const,
            text: JSON.stringify(status, null, 2),
          },
        ],
      };
    }

    case "deploy_to_docker": {
      const params = args as {
        path: string;
        image_name: string;
        container_name?: string;
        port?: number;
        env_vars?: Record<string, string>;
        setup_tunnel?: boolean;
      };

      // Check Docker is running
      const dockerStatus = await checkDocker();
      if (!dockerStatus.running) {
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({
                success: false,
                error: "Docker daemon is not running",
                suggestion: "Start Docker Desktop or run 'dockerd'",
              }),
            },
          ],
        };
      }

      // Check Dockerfile exists
      if (!existsSync(join(params.path, "Dockerfile"))) {
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({
                success: false,
                error: "Dockerfile not found",
                suggestion: "Use generate_dockerfile to create one",
              }),
            },
          ],
        };
      }

      const containerName = params.container_name || params.image_name;
      const port = params.port || 3000;

      // Build image
      const buildResult = await buildDockerImage(params.path, params.image_name);
      if (!buildResult.success) {
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({
                success: false,
                phase: "build",
                error: buildResult.error,
                logs: buildResult.logs.slice(-20),
              }),
            },
          ],
        };
      }

      // Run container
      const runResult = await runDockerContainer(
        `${params.image_name}:latest`,
        containerName,
        port,
        params.env_vars || {}
      );

      if (!runResult.success) {
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({
                success: false,
                phase: "run",
                error: runResult.error,
              }),
            },
          ],
        };
      }

      const result: Record<string, unknown> = {
        success: true,
        image: params.image_name,
        container: containerName,
        containerId: runResult.containerId,
        port,
        url: `http://localhost:${port}`,
      };

      // Set up tunnel if requested
      if (params.setup_tunnel) {
        const tunnelCheck = await checkCli("cloudflared");
        if (tunnelCheck.installed) {
          result.tunnel_note =
            "Use setup_cloudflare_tunnel tool to create a named tunnel for persistent access";
        } else {
          result.tunnel_note =
            "Install cloudflared CLI for tunnel support: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/";
        }
      }

      return {
        content: [
          {
            type: "text" as const,
            text: JSON.stringify(result, null, 2),
          },
        ],
      };
    }

    case "check_platform_cli": {
      const params = args as { platform: string };

      const authChecks: Record<string, string[]> = {
        vercel: ["whoami"],
        railway: ["whoami"],
        fly: ["auth", "whoami"],
        cloudflared: ["tunnel", "list"],
      };

      const result = await checkCli(params.platform, authChecks[params.platform]);

      return {
        content: [
          {
            type: "text" as const,
            text: JSON.stringify(
              {
                platform: params.platform,
                ...result,
                auth_command: result.installed && !result.authenticated
                  ? `${params.platform} login`
                  : null,
              },
              null,
              2
            ),
          },
        ],
      };
    }

    case "deploy_to_vercel": {
      const params = args as {
        path: string;
        production?: boolean;
        env_vars?: Record<string, string>;
      };

      const cliCheck = await checkCli("vercel", ["whoami"]);
      if (!cliCheck.installed) {
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({
                success: false,
                error: "Vercel CLI not installed",
                suggestion: "Install with: npm i -g vercel",
              }),
            },
          ],
        };
      }

      if (!cliCheck.authenticated) {
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({
                success: false,
                error: "Not authenticated with Vercel",
                suggestion: "Run: vercel login",
              }),
            },
          ],
        };
      }

      try {
        const args = params.production ? ["--prod"] : [];
        args.push("--yes"); // Skip prompts

        const { stdout } = await execa("vercel", args, { cwd: params.path });

        // Extract URL from output
        const urlMatch = stdout.match(/https:\/\/[^\s]+/);
        const url = urlMatch ? urlMatch[0] : null;

        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({
                success: true,
                production: params.production || false,
                url,
                output: stdout,
              }, null, 2),
            },
          ],
        };
      } catch (error) {
        const execaError = error as ExecaError;
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({
                success: false,
                error: execaError.message,
                stderr: execaError.stderr,
              }),
            },
          ],
        };
      }
    }

    case "deploy_to_railway": {
      const params = args as { path: string; service_name?: string };

      const cliCheck = await checkCli("railway", ["whoami"]);
      if (!cliCheck.installed) {
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({
                success: false,
                error: "Railway CLI not installed",
                suggestion: "Install with: npm i -g @railway/cli",
              }),
            },
          ],
        };
      }

      if (!cliCheck.authenticated) {
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({
                success: false,
                error: "Not authenticated with Railway",
                suggestion: "Run: railway login",
              }),
            },
          ],
        };
      }

      try {
        const { stdout } = await execa("railway", ["up", "--detach"], {
          cwd: params.path,
        });

        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({
                success: true,
                output: stdout,
                note: "Use 'railway open' to view deployment in browser",
              }, null, 2),
            },
          ],
        };
      } catch (error) {
        const execaError = error as ExecaError;
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({
                success: false,
                error: execaError.message,
                stderr: execaError.stderr,
              }),
            },
          ],
        };
      }
    }

    case "deploy_to_fly": {
      const params = args as { path: string; app_name?: string; region?: string };

      const cliCheck = await checkCli("fly", ["auth", "whoami"]);
      if (!cliCheck.installed) {
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({
                success: false,
                error: "Fly CLI not installed",
                suggestion: "Install from: https://fly.io/docs/hands-on/install-flyctl/",
              }),
            },
          ],
        };
      }

      if (!cliCheck.authenticated) {
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({
                success: false,
                error: "Not authenticated with Fly.io",
                suggestion: "Run: fly auth login",
              }),
            },
          ],
        };
      }

      try {
        // Check if fly.toml exists, if not launch new app
        const flyTomlPath = join(params.path, "fly.toml");
        if (!existsSync(flyTomlPath)) {
          const launchArgs = ["launch", "--no-deploy", "--yes"];
          if (params.app_name) launchArgs.push("--name", params.app_name);
          if (params.region) launchArgs.push("--region", params.region);

          await execa("fly", launchArgs, { cwd: params.path });
        }

        // Deploy
        const { stdout } = await execa("fly", ["deploy"], { cwd: params.path });

        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({
                success: true,
                output: stdout,
              }, null, 2),
            },
          ],
        };
      } catch (error) {
        const execaError = error as ExecaError;
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({
                success: false,
                error: execaError.message,
                stderr: execaError.stderr,
              }),
            },
          ],
        };
      }
    }

    case "setup_cloudflare_tunnel": {
      const params = args as {
        tunnel_name: string;
        local_port: number;
        hostname?: string;
      };

      const cliCheck = await checkCli("cloudflared", ["tunnel", "list"]);
      if (!cliCheck.installed) {
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({
                success: false,
                error: "cloudflared CLI not installed",
                suggestion:
                  "Install from: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/",
              }),
            },
          ],
        };
      }

      if (!cliCheck.authenticated) {
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({
                success: false,
                error: "Not authenticated with Cloudflare",
                suggestion: "Run: cloudflared tunnel login",
              }),
            },
          ],
        };
      }

      try {
        // Create tunnel
        const { stdout: createOutput } = await execa("cloudflared", [
          "tunnel",
          "create",
          params.tunnel_name,
        ]);

        // Get tunnel ID from output
        const tunnelIdMatch = createOutput.match(
          /Created tunnel .+ with id ([a-f0-9-]+)/
        );
        const tunnelId = tunnelIdMatch ? tunnelIdMatch[1] : null;

        // Create config file
        const configContent = `tunnel: ${params.tunnel_name}
credentials-file: ~/.cloudflared/${tunnelId}.json

ingress:
  - hostname: ${params.hostname || `${params.tunnel_name}.example.com`}
    service: http://localhost:${params.local_port}
  - service: http_status:404
`;

        const configPath = join(
          process.env.HOME || process.env.USERPROFILE || "",
          ".cloudflared",
          `${params.tunnel_name}.yml`
        );
        writeFileSync(configPath, configContent);

        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify(
                {
                  success: true,
                  tunnel_name: params.tunnel_name,
                  tunnel_id: tunnelId,
                  config_path: configPath,
                  local_port: params.local_port,
                  next_steps: [
                    params.hostname
                      ? `Add DNS CNAME record: ${params.hostname} -> ${tunnelId}.cfargotunnel.com`
                      : "Add a CNAME record pointing to your tunnel",
                    `Run tunnel: cloudflared tunnel --config ${configPath} run`,
                  ],
                },
                null,
                2
              ),
            },
          ],
        };
      } catch (error) {
        const execaError = error as ExecaError;
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({
                success: false,
                error: execaError.message,
                stderr: execaError.stderr,
              }),
            },
          ],
        };
      }
    }

    case "get_deployment_status": {
      const params = args as { type: string; name: string };

      if (params.type === "docker") {
        const status = await getContainerHealth(params.name);
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify(
                {
                  type: "docker",
                  name: params.name,
                  ...status,
                },
                null,
                2
              ),
            },
          ],
        };
      }

      // For platform deployments, use their CLIs
      try {
        let stdout: string;
        switch (params.type) {
          case "vercel":
            ({ stdout } = await execa("vercel", ["inspect", params.name]));
            break;
          case "railway":
            ({ stdout } = await execa("railway", ["status"]));
            break;
          case "fly":
            ({ stdout } = await execa("fly", ["status", "-a", params.name]));
            break;
          default:
            return {
              content: [
                {
                  type: "text" as const,
                  text: JSON.stringify({ error: `Unknown type: ${params.type}` }),
                },
              ],
            };
        }

        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({ type: params.type, name: params.name, status: stdout }, null, 2),
            },
          ],
        };
      } catch (error) {
        const execaError = error as ExecaError;
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({
                type: params.type,
                name: params.name,
                error: execaError.message,
              }),
            },
          ],
        };
      }
    }

    case "get_deployment_logs": {
      const params = args as { type: string; name: string; tail?: number };
      const tail = params.tail || 100;

      if (params.type === "docker") {
        try {
          const container = docker.getContainer(params.name);
          const logs = await container.logs({
            stdout: true,
            stderr: true,
            tail,
          });

          return {
            content: [
              {
                type: "text" as const,
                text: JSON.stringify(
                  {
                    type: "docker",
                    name: params.name,
                    logs: logs.toString("utf-8"),
                  },
                  null,
                  2
                ),
              },
            ],
          };
        } catch (error) {
          return {
            content: [
              {
                type: "text" as const,
                text: JSON.stringify({
                  error: error instanceof Error ? error.message : "Failed to get logs",
                }),
              },
            ],
          };
        }
      }

      // For platform deployments
      try {
        let stdout: string;
        switch (params.type) {
          case "fly":
            ({ stdout } = await execa("fly", ["logs", "-a", params.name, "-n", String(tail)]));
            break;
          default:
            return {
              content: [
                {
                  type: "text" as const,
                  text: JSON.stringify({
                    error: `Log retrieval not supported for ${params.type} via CLI`,
                    suggestion: "Check the platform dashboard for logs",
                  }),
                },
              ],
            };
        }

        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({ type: params.type, name: params.name, logs: stdout }, null, 2),
            },
          ],
        };
      } catch (error) {
        const execaError = error as ExecaError;
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({ error: execaError.message }),
            },
          ],
        };
      }
    }

    case "stop_deployment": {
      const params = args as { type: string; name: string };

      if (params.type === "docker") {
        try {
          const container = docker.getContainer(params.name);
          await container.stop();
          return {
            content: [
              {
                type: "text" as const,
                text: JSON.stringify({
                  success: true,
                  type: "docker",
                  name: params.name,
                  action: "stopped",
                }),
              },
            ],
          };
        } catch (error) {
          return {
            content: [
              {
                type: "text" as const,
                text: JSON.stringify({
                  success: false,
                  error: error instanceof Error ? error.message : "Failed to stop container",
                }),
              },
            ],
          };
        }
      }

      // For platform deployments
      try {
        switch (params.type) {
          case "fly":
            await execa("fly", ["scale", "count", "0", "-a", params.name]);
            break;
          default:
            return {
              content: [
                {
                  type: "text" as const,
                  text: JSON.stringify({
                    error: `Stop not supported for ${params.type} via CLI`,
                    suggestion: "Use the platform dashboard to stop the deployment",
                  }),
                },
              ],
            };
        }

        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({
                success: true,
                type: params.type,
                name: params.name,
                action: "stopped",
              }),
            },
          ],
        };
      } catch (error) {
        const execaError = error as ExecaError;
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({ success: false, error: execaError.message }),
            },
          ],
        };
      }
    }

    default:
      return null;
  }
}
