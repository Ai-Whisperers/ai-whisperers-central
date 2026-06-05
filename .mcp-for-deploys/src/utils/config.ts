/**
 * Claude Code CLI configuration utilities
 *
 * Handles detection and modification of Claude Code settings
 * for MCP server registration.
 */

import { existsSync, readFileSync, writeFileSync, mkdirSync } from "fs";
import { homedir } from "os";
import { join, dirname } from "path";

export interface McpServerConfig {
  command: string;
  args?: string[];
  cwd?: string;
  env?: Record<string, string>;
}

export interface ClaudeSettings {
  mcpServers?: Record<string, McpServerConfig>;
  [key: string]: unknown;
}

/**
 * Get the path to Claude Code settings.json
 * This is the primary target for CLI integration
 */
export function getClaudeCodeSettingsPath(): string {
  return join(homedir(), ".claude", "settings.json");
}

/**
 * Get the path to Claude Desktop config (secondary target)
 */
export function getClaudeDesktopConfigPath(): string | null {
  const platform = process.platform;

  if (platform === "win32") {
    const appData = process.env.APPDATA;
    if (appData) {
      return join(appData, "Claude", "claude_desktop_config.json");
    }
  } else if (platform === "darwin") {
    return join(
      homedir(),
      "Library",
      "Application Support",
      "Claude",
      "claude_desktop_config.json"
    );
  } else if (platform === "linux") {
    return join(homedir(), ".config", "Claude", "claude_desktop_config.json");
  }

  return null;
}

/**
 * Read Claude Code settings
 */
export function readClaudeSettings(path: string): ClaudeSettings {
  if (!existsSync(path)) {
    return {};
  }

  try {
    const content = readFileSync(path, "utf-8");
    return JSON.parse(content) as ClaudeSettings;
  } catch {
    return {};
  }
}

/**
 * Write Claude Code settings
 */
export function writeClaudeSettings(
  path: string,
  settings: ClaudeSettings
): void {
  const dir = dirname(path);
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }

  writeFileSync(path, JSON.stringify(settings, null, 2));
}

/**
 * Get the Launch MCP server configuration
 * Detects if running locally or from npm and configures accordingly
 */
export function getLaunchServerConfig(): McpServerConfig {
  // Check if we're in a local development context
  const scriptPath = process.argv[1];

  if (scriptPath && scriptPath.includes("dist")) {
    // Local development - use node with absolute path to server
    const serverPath = join(dirname(dirname(scriptPath)), "index.js");
    return {
      command: "node",
      args: [serverPath],
    };
  }

  // Published package - use npx
  return {
    command: "npx",
    args: ["launch-mcp"],
  };
}

/**
 * Check if Launch is already registered
 */
export function isLaunchRegistered(settings: ClaudeSettings): boolean {
  return settings.mcpServers?.["launch"] !== undefined;
}

/**
 * Register Launch MCP server in settings
 */
export function registerLaunch(settings: ClaudeSettings): ClaudeSettings {
  return {
    ...settings,
    mcpServers: {
      ...settings.mcpServers,
      launch: getLaunchServerConfig(),
    },
  };
}

/**
 * Unregister Launch MCP server from settings
 */
export function unregisterLaunch(settings: ClaudeSettings): ClaudeSettings {
  if (!settings.mcpServers) {
    return settings;
  }

  const { launch: _, ...rest } = settings.mcpServers;
  return {
    ...settings,
    mcpServers: rest,
  };
}
