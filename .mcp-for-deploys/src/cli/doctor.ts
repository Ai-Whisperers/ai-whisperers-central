/**
 * Doctor Command - Check system requirements and configuration
 */

import chalk from "chalk";
import { existsSync } from "fs";
import { execSync } from "child_process";
import {
  getClaudeCodeSettingsPath,
  getClaudeDesktopConfigPath,
  readClaudeSettings,
  isLaunchRegistered,
} from "../utils/config.js";
import { VERSION } from "../utils/version.js";

interface DoctorOptions {
  verbose?: boolean;
}

interface CheckResult {
  name: string;
  status: "pass" | "warn" | "fail";
  message: string;
  details?: string;
}

/**
 * Check if a command exists
 */
function commandExists(command: string): boolean {
  try {
    execSync(`where ${command}`, { stdio: "ignore" });
    return true;
  } catch {
    try {
      execSync(`which ${command}`, { stdio: "ignore" });
      return true;
    } catch {
      return false;
    }
  }
}

/**
 * Get command version
 */
function getCommandVersion(command: string, versionFlag = "--version"): string | null {
  try {
    const output = execSync(`${command} ${versionFlag}`, {
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
    });
    return output.trim().split("\n")[0];
  } catch {
    return null;
  }
}

/**
 * Run doctor checks
 */
export async function doctor(options: DoctorOptions): Promise<void> {
  console.log(chalk.cyan(`\nLaunch MCP Doctor v${VERSION}\n`));

  const checks: CheckResult[] = [];

  // Check Node.js
  const nodeVersion = getCommandVersion("node", "-v");
  if (nodeVersion) {
    const majorVersion = parseInt(nodeVersion.replace("v", "").split(".")[0]);
    if (majorVersion >= 18) {
      checks.push({
        name: "Node.js",
        status: "pass",
        message: `Node.js ${nodeVersion} installed`,
      });
    } else {
      checks.push({
        name: "Node.js",
        status: "warn",
        message: `Node.js ${nodeVersion} - upgrade to v18+ recommended`,
      });
    }
  } else {
    checks.push({
      name: "Node.js",
      status: "fail",
      message: "Node.js not found",
      details: "Install from https://nodejs.org",
    });
  }

  // Check Docker
  if (commandExists("docker")) {
    const dockerVersion = getCommandVersion("docker", "-v");
    checks.push({
      name: "Docker",
      status: "pass",
      message: `Docker installed${dockerVersion ? `: ${dockerVersion}` : ""}`,
    });

    // Check if Docker daemon is running
    try {
      execSync("docker info", { stdio: "ignore" });
      checks.push({
        name: "Docker Daemon",
        status: "pass",
        message: "Docker daemon is running",
      });
    } catch {
      checks.push({
        name: "Docker Daemon",
        status: "warn",
        message: "Docker daemon is not running",
        details: "Start Docker Desktop or run 'dockerd'",
      });
    }
  } else {
    checks.push({
      name: "Docker",
      status: "warn",
      message: "Docker not installed (optional for cloud deployments)",
      details: "Install from https://docker.com for local deployments",
    });
  }

  // Check Git
  if (commandExists("git")) {
    const gitVersion = getCommandVersion("git");
    checks.push({
      name: "Git",
      status: "pass",
      message: `Git installed${gitVersion ? `: ${gitVersion}` : ""}`,
    });
  } else {
    checks.push({
      name: "Git",
      status: "warn",
      message: "Git not installed",
      details: "Install from https://git-scm.com",
    });
  }

  // Check Claude Code CLI registration
  const claudeCodePath = getClaudeCodeSettingsPath();
  if (existsSync(claudeCodePath)) {
    const settings = readClaudeSettings(claudeCodePath);
    if (isLaunchRegistered(settings)) {
      checks.push({
        name: "Claude Code CLI",
        status: "pass",
        message: "Launch is registered",
        details: options.verbose ? claudeCodePath : undefined,
      });
    } else {
      checks.push({
        name: "Claude Code CLI",
        status: "warn",
        message: "Launch is not registered",
        details: "Run 'launch install' to register",
      });
    }
  } else {
    checks.push({
      name: "Claude Code CLI",
      status: "warn",
      message: "Settings file not found",
      details: `Expected at ${claudeCodePath}`,
    });
  }

  // Check Claude Desktop (optional)
  const desktopPath = getClaudeDesktopConfigPath();
  if (desktopPath && existsSync(desktopPath)) {
    const desktopSettings = readClaudeSettings(desktopPath);
    if (isLaunchRegistered(desktopSettings)) {
      checks.push({
        name: "Claude Desktop",
        status: "pass",
        message: "Launch is registered",
      });
    } else {
      checks.push({
        name: "Claude Desktop",
        status: "warn",
        message: "Launch is not registered (optional)",
        details: "Run 'launch install --desktop' to register",
      });
    }
  }

  // Check platform CLIs (optional)
  const platformClis = [
    { name: "Vercel CLI", command: "vercel" },
    { name: "Railway CLI", command: "railway" },
    { name: "Fly CLI", command: "fly" },
    { name: "Cloudflare CLI", command: "cloudflared" },
  ];

  for (const cli of platformClis) {
    if (commandExists(cli.command)) {
      checks.push({
        name: cli.name,
        status: "pass",
        message: "Installed",
      });
    } else if (options.verbose) {
      checks.push({
        name: cli.name,
        status: "warn",
        message: "Not installed (optional)",
      });
    }
  }

  // Print results
  console.log(chalk.bold("System Checks:\n"));

  for (const check of checks) {
    const icon =
      check.status === "pass"
        ? chalk.green("✓")
        : check.status === "warn"
          ? chalk.yellow("!")
          : chalk.red("✗");

    const statusColor =
      check.status === "pass"
        ? chalk.green
        : check.status === "warn"
          ? chalk.yellow
          : chalk.red;

    console.log(`  ${icon} ${chalk.bold(check.name)}: ${statusColor(check.message)}`);

    if (check.details && (options.verbose || check.status !== "pass")) {
      console.log(chalk.dim(`      ${check.details}`));
    }
  }

  // Summary
  const passed = checks.filter((c) => c.status === "pass").length;
  const warnings = checks.filter((c) => c.status === "warn").length;
  const failed = checks.filter((c) => c.status === "fail").length;

  console.log("");
  console.log(
    chalk.dim(
      `  ${passed} passed, ${warnings} warnings, ${failed} failed`
    )
  );

  if (failed > 0) {
    console.log("");
    console.log(chalk.red("Some checks failed. Please resolve before using Launch."));
    process.exit(1);
  }

  if (warnings > 0) {
    console.log("");
    console.log(chalk.yellow("Some optional components are missing."));
  }

  console.log("");
}
